#!/bin/bash
# This is to build rubyluabridge on OSX
#
# requires: 
#     brew install --with-complete --universal lua 
#

ruby extconf.rb --with-lua-include=/usr/local/include --with-lua-lib=/usr/local/lib $@
