import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
from backend.storage import Store, ConflictError
from backend import schema


class StorageTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.path = self.directory / 'pindeck.json'
        self.store = Store(str(self.directory))
    def tearDown(self):
        self.store.close(); self.temp.cleanup()
    def test_create_delete_and_recreate_default(self):
        self.store.load()
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o600)
        self.path.unlink()
        self.assertEqual(self.store.load(seen=True)['data'], schema.defaults())
    def test_legacy_is_imported_once_and_never_resurrected(self):
        old = schema.defaults(); old['folders'] = [{'id':'g','name':'Old'}]
        (self.directory/'pinned.json').write_bytes(schema.encode(old))
        self.assertEqual(self.store.load()['data'], old)
        self.path.unlink()
        self.assertEqual(self.store.load(seen=True)['data'], schema.defaults())
        self.assertTrue((self.directory/'pinned.json').exists())
    def test_conflict_preserves_external_edit(self):
        state = self.store.load()
        changed = schema.defaults(); changed['extra'] = True
        self.path.write_bytes(schema.encode(changed))
        with self.assertRaises(ConflictError): self.store.save(schema.defaults(), state['revision'])
        self.assertEqual(json.loads(self.path.read_bytes()), changed)
    def test_invalid_file_is_never_replaced(self):
        self.path.write_text('{bad')
        with self.assertRaises(ValueError): self.store.load()
        self.assertEqual(self.path.read_text(), '{bad')
    def test_symlink_fifo_hardlink_and_permissions_are_rejected(self):
        victim = self.directory/'victim'; victim.write_text('untouched')
        self.path.symlink_to(victim)
        with self.assertRaises(OSError): self.store.load()
        self.path.unlink(); os.mkfifo(self.path)
        with self.assertRaises(PermissionError): self.store.load()
        self.path.unlink(); os.link(victim, self.path)
        with self.assertRaises(PermissionError): self.store.load()
        self.path.unlink(); self.path.write_bytes(schema.encode(schema.defaults())); self.path.chmod(0o666)
        with self.assertRaises(PermissionError): self.store.load()
        self.assertEqual(victim.read_text(), 'untouched')
    def test_parent_symlink_rejected(self):
        alias = self.directory/'alias'; alias.symlink_to(self.directory, target_is_directory=True)
        with self.assertRaises(OSError): Store(str(alias))
    def test_oversize_rejected_before_reading(self):
        with self.path.open('wb') as output: output.truncate(schema.MAX_BYTES + 1)
        with self.assertRaises(ValueError): self.store.load()
    def test_failed_replace_keeps_prior_bytes_and_removes_temporary(self):
        state = self.store.load(); before = self.path.read_bytes()
        with patch('backend.storage.os.replace', side_effect=OSError('disk failure')):
            with self.assertRaises(OSError): self.store.save(schema.defaults(), state['revision'])
        self.assertEqual(self.path.read_bytes(), before)
        self.assertFalse(list(self.directory.glob('*.tmp')))
    def test_lock_symlink_refused_without_truncating_target(self):
        victim = self.directory/'victim'; victim.write_text('untouched')
        (self.directory/'.pindeck.lock').symlink_to(victim)
        with self.assertRaises(OSError): self.store.load()
        self.assertEqual(victim.read_text(), 'untouched')
    def test_schema_rejects_depth_duplicate_fields_and_nonfinite_values(self):
        for raw in [b'{"version":1,"version":1}', b'['*2000+b']'*2000]:
            with self.assertRaises(ValueError): schema.decode(raw)
        value = schema.defaults(); value['extra'] = float('nan')
        with self.assertRaises(ValueError): schema.encode(value)

if __name__ == '__main__': unittest.main()

class StorageFailuresTest(unittest.TestCase):
    setUp = StorageTest.setUp
    tearDown = StorageTest.tearDown
    def test_held_read_descriptor_cannot_be_redirected_after_open(self):
        state=self.store.load();original=self.path.read_bytes()
        target=self.directory/'victim';target.write_text('not json')
        read=os.read
        switched=False
        def swap(fd,count):
            nonlocal switched
            if not switched:
                switched=True;self.path.unlink();self.path.symlink_to(target)
            return read(fd,count)
        with patch('backend.storage.os.read',side_effect=swap):
            self.assertEqual(self.store.read(),original)
        self.assertEqual(target.read_text(),'not json')
    def test_exclusive_lock_times_out(self):
        import fcntl
        with self.store.locked():
            with self.assertRaises(TimeoutError):
                with self.store.locked(): pass
    def test_short_writes_are_completed(self):
        state=self.store.load();write=os.write
        with patch('backend.storage.os.write',side_effect=lambda fd,data:write(fd,data[:3])):
            self.store.save(schema.defaults(),state['revision'])
        self.assertEqual(json.loads(self.path.read_bytes()),schema.defaults())
    def test_zero_write_and_fsync_failure_preserve_existing_file(self):
        state=self.store.load();before=self.path.read_bytes()
        with patch('backend.storage.os.write',return_value=0):
            with self.assertRaises(OSError): self.store.save(schema.defaults(),state['revision'])
        self.assertEqual(self.path.read_bytes(),before)
        with patch('backend.storage.os.fsync',side_effect=OSError('failure')):
            with self.assertRaises(OSError): self.store.save(schema.defaults(),state['revision'])
        self.assertEqual(self.path.read_bytes(),before)
    def test_inline_import_and_world_readable_legacy_upgrade(self):
        legacy=schema.defaults();legacy['folders']=[{'id':'old','name':'Inline'}]
        loaded=self.store.load(legacy=legacy)
        self.assertEqual(loaded['data'],legacy)
        self.path.chmod(0o644)
        self.store.save(legacy,loaded['revision'])
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode),0o600)
