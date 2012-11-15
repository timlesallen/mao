# encoding: utf-8
require 'spec_helper'

describe Mao do
  before { prepare_spec }

  describe ".connect!" do
    let(:options) { double("options") }
    let(:conn) { double("conn") }
    before { PG.should_receive(:connect).with(options).and_return(conn) }
    before { conn.should_receive(:internal_encoding=).with(Encoding::UTF_8) }
    before { Mao.disconnect! rescue false }
    it { Mao.connect!(options) }
    after { Mao.instance_variable_set("@conn", nil) }
  end

  describe ".disconnect!" do
    before { PG::Connection.any_instance.should_receive(:close) }
    it { Mao.disconnect! }
  end

  describe ".sql" do
    before { PG::Connection.any_instance.should_receive(:exec).
                 with(:x).and_return(:y) }
    it { Mao.sql(:x).should eq :y }
  end

  describe ".quote_ident" do
    context "pass-thru" do
      before { PG::Connection.any_instance.should_receive(:quote_ident).
                   with("table").and_return(%q{"table"}) }
      it { Mao.quote_ident("table").should eq %q{"table"} }
    end

    context "Symbols" do
      before { PG::Connection.any_instance.should_receive(:quote_ident).
                   with("table").and_return(%q{"table"}) }
      it { Mao.quote_ident(:table).should eq %q{"table"} }
    end
  end

  describe ".escape_literal" do
    describe "verify pass-thru String" do
      before { PG::Connection.any_instance.should_receive(:escape_literal).
                   with("table").and_return(%q{'table'}) }
      it { Mao.escape_literal("table").should eq %q{'table'} }
    end

    describe "verify not pass-thru others" do
      before { PG::Connection.any_instance.
                   should_not_receive(:escape_literal) }
      it { Mao.escape_literal(nil).should eq "null" }
    end

    describe "verify escape_literal-less PG::Connection" do
      before { PG::Connection.any_instance.should_receive(:respond_to?).
                   with(:escape_literal).and_return(false) }
      before { PG::Connection.any_instance.should_receive(:escape_string).
                   with("xyz'hah").and_return("xyz''hah") }
      it { Mao.escape_literal("xyz'hah").should eq %q{'xyz''hah'} }
    end

    describe "actual values" do
      it { Mao.escape_literal("table").should eq %q{'table'} }
      it { Mao.escape_literal(42).should eq %q{42} }
      it { Mao.escape_literal(true).should eq %q{true} }
      it { Mao.escape_literal(false).should eq %q{false} }
      it { Mao.escape_literal(nil).should eq %q{null} }
      it { Mao.escape_literal([]).should eq %q{(null)} }
      it { Mao.escape_literal([1]).should eq %q{(1)} }
      it { Mao.escape_literal([1, "xzy"]).should eq %q{(1, 'xzy')} }
      it { Mao.escape_literal(Mao::Query.raw("\n\"'%")).should eq "\n\"'%" }

      # Times are escaped to UTC always.
      it { Mao.escape_literal(Time.new(2012, 11, 11, 6, 45, 0, 11 * 3600)).
               should eq %q{'2012-11-10 19:45:00.000000'} }
      it { Mao.escape_literal(Time.new(2012, 11, 10, 19, 45, 0, 0)).
               should eq %q{'2012-11-10 19:45:00.000000'} }
      it { Mao.escape_literal(Time.new(2012, 11, 10, 19, 45, 0.1, 0)).
               should eq %q{'2012-11-10 19:45:00.100000'} }
    end
  end

  describe ".query" do
    subject { Mao.query(:empty) }
    it { should be_an_instance_of Mao::Query }
    it { should be_frozen }
  end

  describe ".transaction" do
    context "empty" do
      before { PG::Connection.any_instance.should_receive(:exec).
                   with("BEGIN") }
      before { PG::Connection.any_instance.should_receive(:exec).
                   with("COMMIT") }
      it { Mao.transaction {} }
    end

    context "success" do
      before { Mao.should_receive(:sql).with("BEGIN") }
      before { Mao.should_receive(:sql).with(:some_sql).and_return :ok }
      before { Mao.should_receive(:sql).with("COMMIT") }
      it { Mao.transaction { Mao.sql(:some_sql) }.
               should eq :ok }
    end

    context "failure" do
      before { Mao.should_receive(:sql).with("BEGIN") }
      before { Mao.should_receive(:sql).with(:some_sql).
                   and_raise(Exception.new) }
      before { Mao.should_receive(:sql).with("ROLLBACK") }
      it { expect { Mao.transaction { Mao.sql(:some_sql) }
                  }.to raise_exception }
    end

    context "rollback" do
      before { Mao.should_receive(:sql).with("BEGIN") }
      before { Mao.should_receive(:sql).with(:some_sql).
                   and_raise(Mao::Rollback) }
      before { Mao.should_receive(:sql).with("ROLLBACK") }
      it { expect { Mao.transaction { Mao.sql(:some_sql) }
                  }.to_not raise_exception }
    end

    context "nested transactions" do
      # Currently not supported: the inner transactions don't add transactions
      # at all.
      before { Mao.should_receive(:sql).with("BEGIN").once }
      before { Mao.should_receive(:sql).with("ROLLBACK").once }

      it do
        Mao.transaction { Mao.transaction { raise Mao::Rollback } }.
            should be_false
      end
    end
  end

  describe ".normalize_result" do
    before { Mao.should_receive(:convert_type).
                 with("y", "zzz").and_return("q") }
    it { Mao.normalize_result({"x" => "y"}, {:x => "zzz"}).
             should eq({:x => "q"}) }
  end

  describe ".normalize_join_result" do
    let(:from) { double("from") }
    let(:to) { double("to") }

    before { from.should_receive(:table).and_return(:from) }
    before { from.should_receive(:col_types).and_return({:a => "integer"}) }
    before { to.should_receive(:table).and_return(:to) }
    before { to.should_receive(:col_types).
                 and_return({:b => "character varying"}) }

    it { Mao.normalize_join_result(
             {"c1" => "1", "c2" => "2"}, from, to).
             should eq({:from => {:a => 1},
                        :to => {:b => "2"}}) }

    it { Mao.normalize_join_result(
             {"c1" => "1"}, from, to).
             should eq({:from => {:a => 1}}) }
  end

  describe ".convert_type" do
    context "integers" do
      it { Mao.convert_type(nil, "integer").should be_nil }
      it { Mao.convert_type("42", "integer").should eq 42 }
      it { Mao.convert_type("42", "smallint").should eq 42 }
      it { Mao.convert_type("42", "bigint").should eq 42 }
      it { Mao.convert_type("42", "serial").should eq 42 }
      it { Mao.convert_type("42", "bigserial").should eq 42 }
    end

    context "character" do
      it { Mao.convert_type(nil, "character varying").should be_nil }
      it { Mao.convert_type("blah", "character varying").
               should eq "blah" }
      it { Mao.convert_type("blah", "character varying").encoding.
               should be Encoding::UTF_8 }

      it { Mao.convert_type(nil, "character varying(200)").should be_nil }
      it { Mao.convert_type("blah", "character varying(200)").
               should eq "blah" }
      it { Mao.convert_type("blah", "character varying(200)").encoding.
               should be Encoding::UTF_8 }

      it { Mao.convert_type(nil, "text").should be_nil }
      it { Mao.convert_type("blah", "text").
               should eq "blah" }
      it { Mao.convert_type("blah", "text").encoding.
               should be Encoding::UTF_8 }
    end

    context "dates" do
      it { Mao.convert_type(nil, "timestamp without time zone").
               should be_nil }
      # Note: without timezone is assumed to be in UTC.
      it { Mao.convert_type("2012-11-10 19:45:00",
                             "timestamp without time zone").
               should eq Time.new(2012, 11, 10, 19, 45, 0, 0) }
      it { Mao.convert_type("2012-11-10 19:45:00.1",
                             "timestamp without time zone").
               should eq Time.new(2012, 11, 10, 19, 45, 0.1, 0) }
    end

    context "booleans" do
      it { Mao.convert_type(nil, "boolean").should be_nil }
      it { Mao.convert_type("t", "boolean").should eq true }
      it { Mao.convert_type("f", "boolean").should eq false }
    end

    context "bytea" do
      it { Mao.convert_type(nil, "bytea").should be_nil }
      it { Mao.convert_type("\\x5748415400", "bytea").should eq "WHAT\x00" }
      it { Mao.convert_type("\\x5748415400", "bytea").encoding.
               should eq Encoding::ASCII_8BIT }
    end

    context "numeric" do
      it { Mao.convert_type(nil, "numeric").should be_nil }
      it { Mao.convert_type("1234567890123456.789", "numeric").
               should eq BigDecimal.new("1234567890123456.789") }
    end
  end
end

# vim: set sw=2 cc=80 et:
