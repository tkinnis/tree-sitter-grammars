import re
import unittest


class ParseTest(unittest.TestCase):
    flags = re.ASCII

    def run_once(self):
        return self.parser.parse()
