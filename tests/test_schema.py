import copy
import json
import unittest
from backend import schema

class SchemaTest(unittest.TestCase):
    def test_valid_commands_folders_copies_and_unknown_fields(self):
        data=schema.defaults()
        data['folders']=[{'id':'__proto__','name':'Group','expanded':False}]
        data['pinnedApps']=[{'id':'app','name':'App'},{'id':'app','pinId':'copy','folderId':'__proto__','name':'App'},
            {'id':'cmd','name':'Command','kind':'command','commandText':'echo hello'},
            {'id':'loc','name':'Folder','kind':'location','path':'/tmp','icon':'folder'}]
        data['extra']={'nested':[True,None,1.5]}
        self.assertEqual(schema.decode(schema.encode(data)),data)
    def test_each_schema_boundary(self):
        cases=[None,[],{'version':True},dict(schema.defaults(),version=2),dict(schema.defaults(),folders=[None]),
            dict(schema.defaults(),folders=[{'id':'g','name':'G','expanded':'false'}]),
            dict(schema.defaults(),folders=[{'id':'g','name':'G'}]*2),dict(schema.defaults(),rootOrder=[3]),
            dict(schema.defaults(),pinnedApps=[None]),dict(schema.defaults(),pinnedApps=[{'id':'x','name':'X'}]*2)]
        for changes in [{'kind':'unknown'},{'name':'x'*257},{'id':'bad\0'},{'kind':'location','path':'relative'},
            {'kind':'command','commandText':' '},{'runInTerminal':'yes'},{'icon':3},{'folderId':3},
            {'pinId':''},{'commandText':'x'*16385,'kind':'command'}]:
            cases.append(dict(schema.defaults(),pinnedApps=[dict({'id':'x','name':'X'},**changes)]))
        for value in cases:
            with self.subTest(value=str(value)[:100]),self.assertRaises(ValueError): schema.validate(value)
    def test_count_depth_and_byte_limits(self):
        data=schema.defaults();data['folders']=[{'id':str(i),'name':'G'} for i in range(101)]
        with self.assertRaises(ValueError): schema.validate(data)
        data=schema.defaults();extra={};data['extra']=extra
        for i in range(18): extra['nested']={};extra=extra['nested']
        with self.assertRaises(ValueError): schema.validate(data)
        with self.assertRaises(ValueError): schema.decode(b' '* (schema.MAX_BYTES+1))
        data=schema.defaults();data['extra']='x'*schema.MAX_BYTES
        with self.assertRaises(ValueError): schema.encode(data)
        with self.assertRaises(ValueError): schema.decode(b'\xff')
