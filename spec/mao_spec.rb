# encoding: utf-8
require 'spec_helper'

describe Mao do
  before { prepare_spec }

  describe ".connect!" do
    let(:options) { double("options") }
    let(:conn) { double("conn") }
    before { expect(PG).to receive(:connect).with(options).and_return(conn) }
    before { expect(conn).to receive(:internal_encoding=).with(Encoding::UTF_8) }
    before { Mao.disconnect! rescue false }
    it { Mao.connect!(options) }
    after { Mao.instance_variable_set("@conn", nil) }
  end

  describe ".disconnect!" do
    before { expect_any_instance_of(PG::Connection).to receive(:close) }
    it { Mao.disconnect! }
  end

  describe ".sql" do
    before { expect_any_instance_of(PG::Connection).to receive(:exec).
                 with(:x).and_return(:y) }
    it { expect(Mao.sql(:x)).to eq :y }
  end

  describe ".quote_ident" do
    context "pass-thru" do
      before { expect_any_instance_of(PG::Connection).to receive(:quote_ident).
                   with("table").and_return(%q{"table"}) }
      it { expect(Mao.quote_ident("table")).to eq %q{"table"} }
    end

    context "Symbols" do
      before { expect_any_instance_of(PG::Connection).to receive(:quote_ident).
                   with("table").and_return(%q{"table"}) }
      it { expect(Mao.quote_ident(:table)).to eq %q{"table"} }
    end
  end

  describe ".escape_literal" do
    describe "verify pass-thru String" do
      before { expect_any_instance_of(PG::Connection).to receive(:escape_literal).
                   with("table").and_return(%q{'table'}) }
      it { expect(Mao.escape_literal("table")).to eq %q{'table'} }
    end

    describe "verify not pass-thru others" do
      before { expect_any_instance_of(PG::Connection).
                   not_to receive(:escape_literal) }
      it { expect(Mao.escape_literal(nil)).to eq "null" }
    end

    describe "verify escape_literal-less PG::Connection" do
      before { expect_any_instance_of(PG::Connection).to receive(:respond_to?).
                   with(:escape_literal).and_return(false) }
      before { expect_any_instance_of(PG::Connection).to receive(:escape_string).
                   with("xyz'hah").and_return("xyz''hah") }
      it { expect(Mao.escape_literal("xyz'hah")).to eq %q{'xyz''hah'} }
    end

    describe "actual values" do
      it { expect(Mao.escape_literal("table")).to eq %q{'table'} }
      it { expect(Mao.escape_literal(42)).to eq %q{42} }
      it { expect(Mao.escape_literal(true)).to eq %q{true} }
      it { expect(Mao.escape_literal(false)).to eq %q{false} }
      it { expect(Mao.escape_literal(nil)).to eq %q{null} }
      it { expect(Mao.escape_literal([])).to eq %q{(null)} }
      it { expect(Mao.escape_literal([1])).to eq %q{(1)} }
      it { expect(Mao.escape_literal([1, "xzy"])).to eq %q{(1, 'xzy')} }
      it { expect(Mao.escape_literal(Mao::Query.raw("\n\"'%"))).to eq "\n\"'%" }

      # Times are escaped to UTC always.
      it { expect(Mao.escape_literal(Time.new(2012, 11, 11, 6, 45, 0, 11 * 3600))).
               to eq %q{'2012-11-10 19:45:00.000000'} }
      it { expect(Mao.escape_literal(Time.new(2012, 11, 10, 19, 45, 0, 0))).
               to eq %q{'2012-11-10 19:45:00.000000'} }
      it { expect(Mao.escape_literal(Time.new(2012, 11, 10, 19, 45, 0.1, 0))).
               to eq %q{'2012-11-10 19:45:00.100000'} }
    end
  end

  describe ".query" do
    subject { Mao.query(:empty) }
    it { is_expected.to be_an_instance_of Mao::Query }
    it { is_expected.to be_frozen }
  end

  describe ".transaction" do
    context "empty" do
      before { expect_any_instance_of(PG::Connection).to receive(:exec).
                   with("BEGIN") }
      before { expect_any_instance_of(PG::Connection).to receive(:exec).
                   with("COMMIT") }
      it { Mao.transaction {} }
    end

    context "success" do
      before { expect(Mao).to receive(:sql).with("BEGIN") }
      before { expect(Mao).to receive(:sql).with(:some_sql).and_return :ok }
      before { expect(Mao).to receive(:sql).with("COMMIT") }
      it { expect(Mao.transaction { Mao.sql(:some_sql) }).
               to eq :ok }
    end

    context "failure" do
      before { expect(Mao).to receive(:sql).with("BEGIN") }
      before { expect(Mao).to receive(:sql).with(:some_sql).
                   and_raise(Exception.new) }
      before { expect(Mao).to receive(:sql).with("ROLLBACK") }
      it { expect { Mao.transaction { Mao.sql(:some_sql) }
                  }.to raise_exception }
    end

    context "rollback" do
      before { expect(Mao).to receive(:sql).with("BEGIN") }
      before { expect(Mao).to receive(:sql).with(:some_sql).
                   and_raise(Mao::Rollback) }
      before { expect(Mao).to receive(:sql).with("ROLLBACK") }
      it { expect { Mao.transaction { Mao.sql(:some_sql) }
                  }.to_not raise_exception }
    end

    context "nested transactions" do
      # Currently not supported: the inner transactions don't add transactions
      # at all.
      before { expect(Mao).to receive(:sql).with("BEGIN").once }
      before { expect(Mao).to receive(:sql).with("ROLLBACK").once }

      it do
        expect(Mao.transaction { Mao.transaction { raise Mao::Rollback } }).
            to be_falsey
      end
    end
  end

  describe ".normalize_result" do
    before { expect(Mao).to receive(:convert_type).
                 with("y", "zzz").and_return("q") }
    it { expect(Mao.normalize_result({"x" => "y"}, {:x => "zzz"})).
             to eq({:x => "q"}) }
  end

  describe ".normalize_join_result" do
    let(:from) { double("from") }
    let(:to) { double("to") }

    before { expect(from).to receive(:table).and_return(:from) }
    before { expect(from).to receive(:col_types).and_return({:a => "integer"}) }
    before { expect(to).to receive(:table).and_return(:to) }
    before { expect(to).to receive(:col_types).
                 and_return({:b => "character varying"}) }

    it { expect(Mao.normalize_join_result(
             {"c1" => "1", "c2" => "2"}, from, to)).
             to eq({:from => {:a => 1},
                        :to => {:b => "2"}}) }

    it { expect(Mao.normalize_join_result(
             {"c1" => "1"}, from, to)).
             to eq({:from => {:a => 1}}) }
  end

  describe ".convert_type" do
    context "integers" do
      it { expect(Mao.convert_type(nil, "integer")).to be_nil }
      it { expect(Mao.convert_type("42", "integer")).to eq 42 }
      it { expect(Mao.convert_type("42", "smallint")).to eq 42 }
      it { expect(Mao.convert_type("42", "bigint")).to eq 42 }
      it { expect(Mao.convert_type("42", "serial")).to eq 42 }
      it { expect(Mao.convert_type("42", "bigserial")).to eq 42 }
    end

    context "character" do
      it { expect(Mao.convert_type(nil, "character varying")).to be_nil }
      it { expect(Mao.convert_type("blah", "character varying")).
               to eq "blah" }
      it { expect(Mao.convert_type("blah", "character varying").encoding).
               to be Encoding::UTF_8 }

      it { expect(Mao.convert_type(nil, "character varying(200)")).to be_nil }
      it { expect(Mao.convert_type("blah", "character varying(200)")).
               to eq "blah" }
      it { expect(Mao.convert_type("blah", "character varying(200)").encoding).
               to be Encoding::UTF_8 }

      it { expect(Mao.convert_type(nil, "text")).to be_nil }
      it { expect(Mao.convert_type("blah", "text")).
               to eq "blah" }
      it { expect(Mao.convert_type("blah", "text").encoding).
               to be Encoding::UTF_8 }
    end

    context "dates" do
      it { expect(Mao.convert_type(nil, "timestamp without time zone")).
               to be_nil }
      # Note: without timezone is assumed to be in UTC.
      it { expect(Mao.convert_type("2012-11-10 19:45:00",
                             "timestamp without time zone")).
               to eq Time.new(2012, 11, 10, 19, 45, 0, 0) }
      it { expect(Mao.convert_type("2012-11-10 19:45:00.1",
                             "timestamp without time zone")).
               to eq Time.new(2012, 11, 10, 19, 45, 0.1, 0) }
    end

    context "booleans" do
      it { expect(Mao.convert_type(nil, "boolean")).to be_nil }
      it { expect(Mao.convert_type("t", "boolean")).to eq true }
      it { expect(Mao.convert_type("f", "boolean")).to eq false }
    end

    context "bytea" do
      it { expect(Mao.convert_type(nil, "bytea")).to be_nil }
      it { expect(Mao.convert_type("\\x5748415400", "bytea")).to eq "WHAT\x00" }
      it { expect(Mao.convert_type("\\x5748415400", "bytea").encoding).
               to eq Encoding::ASCII_8BIT }
    end

    context "numeric" do
      it { expect(Mao.convert_type(nil, "numeric")).to be_nil }
      it { expect(Mao.convert_type("1234567890123456.789", "numeric")).
               to eq BigDecimal.new("1234567890123456.789") }
    end
  end
end

# vim: set sw=2 cc=80 et:
