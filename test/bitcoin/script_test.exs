defmodule Bitcoin.ScriptTest do
  use ExUnit.Case

  alias Bitcoin.Protocol.Types
  alias Bitcoin.Protocol.Messages

  alias Bitcoin.Script

  @parsed_scripts %{
    "76A914C398EFA9C392BA6013C5E04EE729755EF7F58B3288AC" =>
    [:OP_DUP, :OP_HASH160, <<195, 152, 239, 169, 195, 146, 186, 96, 19, 197, 224, 78, 231, 41, 117, 94,  247, 245, 139, 50>>, :OP_EQUALVERIFY, :OP_CHECKSIG],

    # Some examples taken from bitcoin-ruby tests (https://github.com/lian/bitcoin-ruby/blob/master/spec/bitcoin/script/script_spec.rb)
    "526B006B7DAC7CA9143CD1DEF404E12A85EAD2B4D3F5F9F817FB0D46EF879A6C93" =>
    [:OP_2, :OP_TOALTSTACK, :OP_FALSE, :OP_TOALTSTACK, :OP_TUCK, :OP_CHECKSIG, :OP_SWAP, :OP_HASH160, <<60, 209, 222, 244, 4, 225, 42, 133, 234, 210, 180, 211, 245, 249, 248, 23,  251, 13, 70, 239>>, :OP_EQUAL, :OP_BOOLAND, :OP_FROMALTSTACK, :OP_ADD],

    "0002FFFFAB5102FFFF51AE" =>
    [:OP_FALSE, <<255, 255>>, :OP_CODESEPARATOR, :OP_TRUE, <<255, 255>>, :OP_TRUE, :OP_CHECKMULTISIG],

    "6A04DEADBEEF" =>
    [:OP_RETURN, <<222, 173, 190, 239>>],
  }


  # From script test cases json file:
  #["It is evaluated as if there was a crediting coinbase transaction with two 0"],
  #["pushes as scriptSig, and one output of 0 satoshi and given scriptPubKey,"],
  #["followed by a spending transaction which spends this output as only input (and"],
  #["correct prevout hash), using the given scriptSig. All nLockTimes are 0, all"],
  #["nSequences are max."],
  def test_script_verify(sig_bin, pk_bin) do

    cred_tx = %Messages.Tx{
      inputs: [
        %Types.TxInput{
          previous_output: %Types.Outpoint{
            hash: <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>,
            index: 0xFF_FF_FF_FF,
          },
          signature_script: <<0, 0>>,
          sequence: 0xFF_FF_FF_FF,
        }
      ],
      outputs: [
        %Types.TxOutput{
          value: 0,
          pk_script: pk_bin,
        }
      ],
      lock_time: 0,
      version: 1
    }

    spend_tx = %Messages.Tx{
      inputs: [
        %Types.TxInput{
          previous_output: %Types.Outpoint{
            hash: cred_tx |> Bitcoin.Tx.hash,
            index: 0
          },
          signature_script: sig_bin,
          sequence: 0xFF_FF_FF_FF,
        }
      ],
      outputs: [
        %Types.TxOutput{
          pk_script: <<>>,
          value: 0
        }
      ],
      lock_time: 0,
      version: 1
    }

    Bitcoin.Script.verify_sig_pk(sig_bin, pk_bin, tx: spend_tx, input_number: 0, sub_script: pk_bin)
  end

  test "parse" do
    @parsed_scripts |> Enum.each(fn {hex, script} ->
      assert Bitcoin.Script.parse(hex |> Base.decode16!) == script
    end)
  end

  test "parse string" do
    [
      {"005163A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A7681468CA4FEC736264C13B859BAC43D5173DF687168287",
         # I admit, a bit of an overkill ;) that's what I had at hand
       "0 1 OP_IF OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ELSE OP_ELSE OP_SHA1 OP_ENDIF 68ca4fec736264c13b859bac43d5173df6871682 OP_EQUAL"
      },
      {"6362675168", "OP_IF OP_VER OP_ELSE 1 OP_ENDIF"},
      {"6365675168", "OP_IF OP_VERIF OP_ELSE 1 OP_ENDIF"} # :invalid
    ] |> Enum.map(fn {hex, string} ->
      assert Bitcoin.Script.parse(hex |> Base.decode16!) == Bitcoin.Script.parse_string(string)
    end)
  end

  test "parse string2" do
    [
      {"-549755813887 SIZE 5 EQUAL", [<<255, 255, 255, 255, 255>>, :OP_SIZE, :OP_5, :OP_EQUAL]},
      {"", []},
      {" EQUAL", [:OP_EQUAL]},
      {" 2    EQUAL     ", [:OP_2, :OP_EQUAL]},
      {"'Az'", ["Az"]}, 
    ] |> Enum.map(fn {string, script} ->
      assert Bitcoin.Script.parse_string2(string) == script
    end)
  end

  test "to binary" do
    ["005163A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A76767A7681468CA4FEC736264C13B859BAC43D5173DF687168287",
      "6362675168", "0100917551", "00483045022015BD0139BCCCF990A6AF6EC5C1C52ED8222E03A0D51C334DF139968525D2FCD20221009F9EFE325476EB64C3958E4713E9EEFE49BF1D820ED58D2112721B134E2A1A5303483045022015BD0139BCCCF990A6AF6EC5C1C52ED8222E03A0D51C334DF139968525D2FCD20221009F9EFE325476EB64C3958E4713E9EEFE49BF1D820ED58D2112721B134E2A1A5303"]
    |> Enum.map(fn hex ->
      bin = hex |> Base.decode16!
      script = bin |> Bitcoin.Script.parse
      assert bin == Bitcoin.Script.to_binary(script)
    end)
  end

  test "run super simple" do
    assert true == [2, 3, :OP_ADD, 5, :OP_EQUAL] |> Bitcoin.Script.verify
    assert false ==[2, 3, :OP_ADD, 4, :OP_EQUAL] |> Bitcoin.Script.verify
  end

  test "disabled op prpsent" do
    assert false == [2, :OP_2MUL] |> Bitcoin.Script.verify
  end

  test "disabled op in unexecuted if branch" do
    assert false == ([:OP_TRUE, :OP_IF, :OP_TRUE, :OP_ELSE, :OP_2, :OP_2MUL, :OP_ENDIF] |> Bitcoin.Script.to_binary |> Bitcoin.Script.verify)
  end

  test "bitcoin core scripts.json" do
    cases = File.read!("test/data/script_tests.json") |> Poison.decode! |> Enum.filter(fn x -> length(x) != 1 end)
    rets = 
      cases
      |> Enum.map(fn [sig_script, pk_script, flags, result | comment ] -> 
        bool_result = result == "OK"
        run_result = try do # try is a lazy way to handle {:errors from parsing
          sig_bin = sig_script |> Bitcoin.Script.Serialization.string2_to_binary
          pk_bin = pk_script |> Bitcoin.Script.Serialization.string2_to_binary
          test_script_verify(sig_bin, pk_bin)
        catch _,_ ->
          false
        end
        run_result == bool_result
      end)
    ok_count = rets |> Enum.filter(fn x -> x == true end) |> Enum.count
    count = cases |> length
    IO.puts "\nBitcoin core script tests: #{ok_count}/#{count}"
  end

  test "bitcore-lib test suite" do
    # source https://raw.githubusercontent.com/bitpay/bitcore-lib/master/test/data/bitcoind/script_valid.json
    # (I think they originally come from BitcoinJ, good stuff
    valid =   File.read!("test/data/script_hex_valid.json")   |> Poison.decode! |> Enum.map(fn x -> [true | x] end)
    invalid = File.read!("test/data/script_hex_invalid.json") |> Poison.decode! |> Enum.map(fn x -> [false | x] end)

    scripts = (valid ++ invalid)
      |> Enum.filter(fn [_,_,_,flags,_] -> !String.contains?(flags, "DISCOURAGE_UPGRADABLE_NOPS") end)
      #|> Enum.filter(fn [_,_,_,flags,_] -> !String.contains?(flags, "MINIMALDATA") end)

    rets = scripts  |> Enum.map(fn [result, sig_hex, pk_hex, flags, _comment] ->

      pk_bin = pk_hex |> String.upcase |> Base.decode16!
      sig_bin = sig_hex |> String.upcase |> Base.decode16!
      ret = test_script_verify(sig_bin, pk_bin) == result
      if !ret do
        # Uncomment to get list of scripts that failed
        #IO.puts "should be #{result} #[#{flags}] | #{comment} :"
        #sig_bin |> IO.inspect |> Bitcoin.Script.parse |> IO.inspect(limit: :infinity) #|> Bitcoin.Script.run |> IO.inspect
        #pk_bin |> IO.inspect |> Bitcoin.Script.parse |> IO.inspect(limit: :infinity) #|> Bitcoin.Script.run |> IO.inspect
        #assert false
      end
      ret
    end)

    ok_count = rets |> Enum.filter(fn x -> x == true end) |> Enum.count
    count = scripts |> length
    IO.puts "\nBitcore-lib script tests: #{ok_count}/#{count}"# (#{fail_count} FAIL, #{count - ok_count - fail_count} BAD)"

  end

end
