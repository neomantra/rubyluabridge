#!/usr/bin/ruby -w

require 'rubyluabridge'
require 'stringio'
require 'test/unit'


class LuaInRuby_Test < Test::Unit::TestCase

    # test module-level entities
    def test_module
        assert_not_nil( Lua::BRIDGE_VERSION )
        assert_not_nil( Lua::BRIDGE_VERSION_NUM )
        assert_not_nil( Lua::LUA_VERSION )
        assert_not_nil( Lua::LUA_RELEASE )        
    end  
    
    
    # test construction of various entities
    def test_construction
        l = Lua::State.new

        assert_instance_of Lua::State, l
        assert_instance_of Lua::Table, l.__globals
        assert_instance_of Lua::Table, l.__registry

        assert_equal l, l.__state
        assert_equal l, l.__globals.__state
        assert_equal l, l.__registry.__state

        assert_luastack_clean l
        
        assert_raise TypeError do
            l_bad = Lua::State.new "aa"    
        end
    end


    # test the basic types
    def test_basic_types
        l = Lua::State.new

        # eval, and basic marshaling
        assert_nil l.eval('return') 
        assert_nil l.eval('return nil') 
        assert_equal 1,     l.eval('return 1') 
        assert_equal 1.1,   l.eval('return 1.1') 
        assert_equal 'abc', l.eval('return "abc"') 
        assert_equal true,  l.eval('return true') 
        assert_equal false, l.eval('return false')
        
        # multi-ret
        a = l.eval_mult( "return" )
        assert_instance_of Array, a
        assert_equal [], a
        assert_equal 0, a.length
        a = l.eval_mult( "return 1" )
        assert_instance_of Array, a
        assert_equal [1], a
        assert_equal 1, a.length
        a = l.eval_mult( "return 1, 2, 3, 4" )
        assert_instance_of Array, a
        assert_equal [1,2,3,4], a
        assert_equal 4, a.length

        # type id
        l.eval <<LUA_END
            f = function() end
            t = {}
            u = io.output() -- userdata
LUA_END
        assert_equal Lua::TFUNCTION, l['f'].__type
        assert_equal Lua::TTABLE,    l.t.__type
        assert_equal Lua::TUSERDATA, l.u.__type
        
       # access queries
        assert_equal true,   l.indexable?
        assert_equal true,   l.new_indexable?
        assert_equal false,  l.callable?
        assert_equal true,   l.t.indexable?
        assert_equal true,   l.t.new_indexable?
        assert_equal false,  l.t.callable?
        assert_equal false,  l['f'].indexable?
        assert_equal false,  l['f'].new_indexable?
        assert_equal true,   l['f'].callable?
        assert_equal true,   l['u'].indexable?
        assert_equal false,  l['u'].new_indexable?
        assert_equal false,  l['u'].callable?

        assert_luastack_clean l
   end    


   # test setters
   def test_setters
       l = Lua::State.new
       
       l.v = 5   ; assert_equal 5, l.v
       l.a = {}  ; assert_instance_of Lua::Table, l.a
       l.a.v = 7 ; assert_equal 7, l.a.v

       l['b']   = 6 ; assert_equal 6, l.b               
       l.a['b'] = 7 ; assert_equal 7, l.a.b               
       
      assert_luastack_clean l                
   end
   
  
   # test libraries
   def test_libraries
           # invoking libraries
        l = Lua::State.new
        assert_nothing_thrown do
            STDOUT << "you should see-> Hello from Lua!-> "
            l.eval( 'print "Hello from Lua!"' )
            STDOUT << "you should see-> Hello again from Lua!-> "
            l.print "Hello again from Lua!"
        end
        assert_luastack_clean l                

        # loading libraries
        #####################
        
        l = Lua::State.new   # all
        count = 0 ; l.__globals.each_key { |k| count += 1 }
        assert_equal 39, count 
        assert_instance_of Lua::RefObject, l['ipairs']  # base library check
        assert_instance_of Lua::Table, l.package
        assert_instance_of Lua::Table, l.table
        assert_instance_of Lua::Table, l.io
        assert_instance_of Lua::Table, l.os
        assert_instance_of Lua::Table, l.string
        assert_instance_of Lua::Table, l.math
        assert_instance_of Lua::Table, l.debug

        l = Lua::State.new( :loadlibs => :all )
        count = 0 ; l.__globals.each_key { |k| count += 1 }
        assert_equal 39, count 
        assert_instance_of Lua::RefObject, l['ipairs']  # base library check
        assert_instance_of Lua::Table, l.package
        assert_instance_of Lua::Table, l.table
        assert_instance_of Lua::Table, l.io
        assert_instance_of Lua::Table, l.os
        assert_instance_of Lua::Table, l.string
        assert_instance_of Lua::Table, l.math
        assert_instance_of Lua::Table, l.debug

        l = Lua::State.new( :loadlibs => :none )
        count = 0 ; l.__globals.each_key { |k| count += 1 }
        assert_equal 0, count 
        
        l = Lua::State.new( :loadlibs => :base )
        assert_instance_of Lua::RefObject, l['ipairs']  # base library check
        assert_equal nil, l.string
        l = Lua::State.new( :loadlibs => :package )
        assert_instance_of Lua::Table, l.package
        assert_equal nil, l.string
        l = Lua::State.new( :loadlibs => :table )
        assert_instance_of Lua::Table, l.table
        assert_equal nil, l.string
        l = Lua::State.new( :loadlibs => :io )
        assert_instance_of Lua::Table, l.io
        assert_equal nil, l.string
        l = Lua::State.new( :loadlibs => :os )
        assert_instance_of Lua::Table, l.os
        assert_equal nil, l.string
        l = Lua::State.new( :loadlibs => :string )
        assert_instance_of Lua::Table, l.string
        assert_equal nil, l.io
        l = Lua::State.new( :loadlibs => :math )
        assert_instance_of Lua::Table, l.math
        assert_equal nil, l.string
        l = Lua::State.new( :loadlibs => :debug )
        assert_instance_of Lua::Table, l.debug
         assert_equal nil, l.string
        
        l = Lua::State.new( :loadlibs => [:base, :package, :io] )
        assert_instance_of Lua::RefObject, l['ipairs']  # base library check
        assert_instance_of Lua::Table, l.package
        assert_instance_of Lua::Table, l.io
    end 


    # test table creation from ruby
    def test_table_creation_from_ruby
        l = Lua::State.new

        l.eval( "a = {}")
        assert_instance_of Lua::Table, l.a

        s = "return {1,2,3}"
        assert_instance_of Lua::Table, l.eval(s)
        assert_equal 3, l.eval(s).__length
        assert_equal [1,2,3], l.eval(s).to_array
        
        b = l.new_table_at 'b'
        assert_instance_of Lua::Table, b
        assert_instance_of Lua::Table, l.b

        b = l.a.new_table_at 'b'
        assert_instance_of Lua::Table, b
        assert_instance_of Lua::Table, l.a.b
        
        l.c = []
        assert_instance_of Lua::Table, l.c
        assert_equal 0, l.c.__length
        
        l.d = {}
        assert_instance_of Lua::Table, l.d
        assert_equal 0, l.d.__length
                
        e = [1,2,3,4]
        l.e = e
        assert_equal 1, l.e[1]
        assert_equal 2, l.e[2]
        assert_equal 3, l.e[3]
        assert_equal 4, l.e[4]
        assert_equal e, l.e.to_array
        assert_instance_of Lua::Table, l.e
    
        f = { 1=>1, 2=>2, 'a'=>3, 'b'=>4 }
        l.f = f
        assert_equal 1, l.f[1]
        assert_equal 2, l.f[2]
        assert_equal 3, l.f['a']
        assert_equal 4, l.f['b']
        assert_equal 2, l.f.__length
        assert_instance_of Lua::Table, l.f
        
        assert_luastack_clean l
    end                
    
    
    # test table accesses
    def test_table_access
        l = Lua::State.new
        l.eval <<LUA_END
            a = { 1, 2, 3, 4 }
            h = { a='x', b='y',
                  [true]  = 'a',
                  [false] = 'b',
                  [1.3]   = 'z', }
            h2 = { a='x', b='y', }
LUA_END

        assert_instance_of Lua::Table, l.a
        assert_instance_of Lua::Table, l.h
        assert_instance_of Lua::Table, l.h2
        assert_instance_of Lua::Table, l['a']
        assert_instance_of Lua::Table, l['h']
        assert_instance_of Lua::Table, l['h2']
                 
        assert_nil      l.a[0]
        assert_equal 1, l.a[1]
        assert_equal 2, l.a[2]
        assert_equal 3, l.a[3]
        assert_equal 4, l.a[4]
        assert_equal 4, l.a.__length

        assert_equal 'x', l.h.a
        assert_equal 'y', l.h.b

        assert_nil        l.h[0]
        assert_equal 'x', l.h['a']
        assert_equal 'y', l.h['b']

        assert_equal 'z', l.h[1.3]
        assert_equal 'a', l.h[true]
        assert_equal 'b', l.h[false]
        assert_equal 0,   l.h.__length  # length only applies to Array

        temp = (l.a[10] = 'x')
        assert_equal 'x', temp
        assert_equal 'x', l.a[10]

        assert_instance_of Array,     l.a.to_array
        assert_instance_of Hash,      l.h2.to_hash
        assert_equal( [1,2,3,4],      l.a.to_array)
        assert_equal( {'a' => 'x','b' => 'y'}, l.h2.to_hash)

        assert_luastack_clean l
    end

    
    # test table iteration
    def test_table_iteration
        l = Lua::State.new

        # array integer iteration
        l.eval( "array = { 100, 200, 300, 400 }" )
        assert_instance_of Lua::Table, l.array                
        n = 0 ; l.array.each_ipair { |k,v| n += 1
            assert_pairs_match( k, v, 1, 100 )
            assert_pairs_match( k, v, 2, 200 )
            assert_pairs_match( k, v, 3, 300 )
            assert_pairs_match( k, v, 4, 400 )
        }
        assert_equal(4, n)         

        n = 0 ; l.array.each_ikey { |k| n += 1
            assert_pairs_match( n, k, 1, 1 )
            assert_pairs_match( n, k, 2, 2 )
            assert_pairs_match( n, k, 3, 3 )
            assert_pairs_match( n, k, 4, 4 )
            assert( n <= 4 )
        }
        assert_equal(4, n)

        sumv = n = 0 ; l.array.each_ivalue { |v| n += 1
            sumv += v
            assert_equal(v, n*100)
        }
        assert_equal(4, n) ; assert_equal(1000, sumv)         

        # hash integer iteration
        l.eval( "hsh = { [1]=100, [2]=200, a=300, b=400, }" )
        assert_instance_of Lua::Table, l.hsh
        n = 0 ; l.hsh.each_ipair { |k,v| n += 1
            assert_pairs_match( k, v, 1, 100 )
            assert_pairs_match( k, v, 2, 200 )
            assert_pairs_match( k, v, 'a', 300 )
            assert_pairs_match( k, v, 'b', 400 )
        }
        assert_equal(2, n)         

        sumk = n = 0 ; l.hsh.each_ikey { |k| n += 1
            sumk += k
        }
        assert_equal(2, n) ; assert_equal(3, sumk)         

        sumv = n = 0 ; l.hsh.each_ivalue { |v| n += 1
            sumv += v
            assert_equal(v, n*100)
        }
        assert_equal(2, n) ; assert_equal(300, sumv)         
                
        # array assoc iteration
        l.eval( "array = { 100, 200, 300, 400 }" )
        assert_instance_of Lua::Table, l.array                
        n = 0 ; l.array.each_pair { |k,v| n += 1
            assert_pairs_match( k, v, 1, 100 )
            assert_pairs_match( k, v, 2, 200 )
            assert_pairs_match( k, v, 3, 300 )
            assert_pairs_match( k, v, 4, 400 )
        }
        assert_equal(4, n)         

        sumk = n = 0 ; l.array.each_key { |k| n += 1
            sumk += k
            assert_equal(k, n)
        }
        assert_equal(4, n) ; assert_equal(10, sumk)         

        sumv = n = 0 ; l.array.each_ivalue { |v| n += 1
            sumv += v
            assert_equal(v, n*100)
        }
        assert_equal(4, n) ; assert_equal(1000, sumv)         

        # hash assoc iteration
        l.eval( "hsh = { [1]=100, [2]=200, a=300, b=400, }" )
        assert_instance_of Lua::Table, l.array                
        n = 0 ; l.hsh.each_pair { |k,v| n += 1
            assert_pairs_match( k, v, 1, 100 )
            assert_pairs_match( k, v, 2, 200 )
            assert_pairs_match( k, v, 'a', 300 )
            assert_pairs_match( k, v, 'b', 400 )
        }
        assert_equal( n, 4)

        n = 0 ; l.hsh.each_key { |k| n += 1 
            assert_pairs_match( n, k, 1, 100 )
            assert_pairs_match( n, k, 2, 200 )
            assert_pairs_match( n, k, 3, 'a' )
            assert_pairs_match( n, k, 4, 'b' )
        }
        assert_equal( n, 4)
        
        n = sumv = 0 ; l.hsh.each_value { |v| n += 1
            sumv += v
        }
        assert_equal(4, n) ; assert_equal( sumv, 1000)

        # done iteration tests
        assert_luastack_clean l
    end


    # test method dispatch
    def test_method_dispatch
        l = Lua::State.new        
        l.eval <<END_OF_LUA
            str = "a"
            function uniret() return 1 end
            function uniret2(a) return a end
            function multiret() return 1, 2, 3 end
            function multiret2(a,b) return 1, a, b end
            
            t = {}
            t.str = "a"
            t.uniret = uniret
            t.uniret2 = uniret2
            t.multiret = multiret
            t.multiret2 = multiret2
END_OF_LUA

        assert_equal 'a', l.str
        assert_equal 'a', l.t.str
        assert_equal 'a', l.str()   # ugly, but Ruby 
        assert_equal 'a', l.t.str() # ugly, but Ruby
        assert_kind_of String, l.str
        assert_kind_of String, l.t.str
        assert_raise RuntimeError do l.str_   end
        assert_raise RuntimeError do l.str!   end
        assert_raise RuntimeError do l.str(2) end
        
        assert_kind_of Lua::RefObject, l['uniret']
        assert_kind_of Float, l.uniret
        assert_kind_of Float, l.uniret_
        assert_equal 1, l.uniret()
        assert_equal 1, l.uniret_
        assert_equal 1, l.t.uniret
        assert_equal 1, l.t.uniret()
        assert_equal 2, l.uniret2(2)
        assert_equal 2, l.t.uniret2(2)
        r = l.uniret2 2 ; assert_equal 2, r
        r = l.t.uniret2 2 ; assert_equal 2, r
                                 
        assert_equal [1,2,3], l.multiret
        assert_equal [1,2,3], l.multiret()
        assert_equal [1,2,3], l.t.multiret
        assert_equal [1,2,3], l.t.multiret()
        assert_equal [1,5,6], l.multiret2( 5, 6 )
        assert_equal [1,5,6], l.t.multiret2( 5, 6 )
        r = l.multiret2 5, 6 ; assert_equal [1,5,6], r
        r = l.t.multiret2 5, 6 ; assert_equal [1,5,6], r

        assert_luastack_clean l
    end
    
    
    # test classes
    def test_classes
        l = Lua::State.new

        l.eval <<END_LUA
            Account = {
                balance = 0,
                deposit = function( self, v )
                print "testing testing testing"
                    self.balance = self.balance + v
                end,
            }
END_LUA
        assert_equal Lua::Table, l.Account.class
        assert_equal 0, l.Account.balance
        assert_nothing_thrown { l.Account.deposit! 100 }
        assert_equal 100, l.Account.balance
        # DO WE WANT TO DO ANYTHING LIKE THIS?
        #assert_nothing_thrown { l.Account.!deposit 50 }
        #assert_equal 150, l.Account.balance
        #assert_nothing_thrown { l.Account.!deposit! 25 }
        #assert_equal 175, l.Account.balance

        assert_luastack_clean l
    end
    
    
    # test exceptions
    def test_exceptions
        l = Lua::State.new

        assert_raise SyntaxError do
            l.eval( 'if !exclamation_doesnt_work then return 0 end' )
        end
       
        assert_raise RuntimeError do
            l.eval( 'error("42")' )
        end

        assert_luastack_clean l
    end

    # test garbage collection
    # makes sure various C-based objects are properly cleaned
    def test_garbage_collection
        50.times do
            l = Lua::State.new
            g = l.__globals
            l = g = nil
            GC.start
        end
    end


    # asserts that the state's stack is empty
    # incorrectly implemented Lua API blocks will trigger this
    def assert_luastack_clean( lstate )
        assert_equal 0, lstate.__top
    end

    # assert that a given key/value pair match an expected key/value pair    
    def assert_pairs_match( key, val, expected_key, expected_val )
        assert_equal(key, expected_key) if val == expected_val
    end
        
end

