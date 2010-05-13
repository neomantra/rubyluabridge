#!/bin/bash
ruby extconf.rb --with-lua-include=/usr/include/lua5.1 --with-lualib=lua5.1 $@
