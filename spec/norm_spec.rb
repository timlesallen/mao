require 'spec_helper'

describe Norm do
  before { prepare_spec }

  describe ".connect!" do
    let(:options) { double("options") }
    before { PG.should_receive(:connect).with(options) }
    before { Norm.disconnect! rescue false }
    it { Norm.connect!(options) }
  end

  describe ".disconnect!" do
    before { PG::Connection.any_instance.should_receive(:close) }
    it { Norm.disconnect! }
  end

  describe ".sql" do
    before { PG::Connection.any_instance.should_receive(:exec).
                 with(:x).and_return(:y) }
    it { Norm.sql(:x).should eq :y }
  end

  describe ".quote_ident" do
    context "pass-thru" do
      before { PG::Connection.any_instance.should_receive(:quote_ident).
                   with("table").and_return(%q{"table"}) }
      it { Norm.quote_ident("table").should eq %q{"table"} }
    end

    context "Symbols" do
      before { PG::Connection.any_instance.should_receive(:quote_ident).
                   with("table").and_return(%q{"table"}) }
      it { Norm.quote_ident(:table).should eq %q{"table"} }
    end
  end

  describe ".escape_literal" do
    describe "verify pass-thru String" do
      before { PG::Connection.any_instance.should_receive(:escape_literal).
                   with("table").and_return(%q{'table'}) }
      it { Norm.escape_literal("table").should eq %q{'table'} }
    end

    describe "verify not pass-thru others" do
      before { PG::Connection.any_instance.
                   should_not_receive(:escape_literal) }
      it { Norm.escape_literal(nil).should eq "null" }
    end

    describe "actual values" do
      it { Norm.escape_literal("table").should eq %q{'table'} }
      it { Norm.escape_literal(42).should eq %q{42} }
      it { Norm.escape_literal(true).should eq %q{true} }
      it { Norm.escape_literal(false).should eq %q{false} }
      it { Norm.escape_literal(nil).should eq %q{null} }
      it { Norm.escape_literal([]).should eq %q{(null)} }
      it { Norm.escape_literal([1]).should eq %q{(1)} }
      it { Norm.escape_literal([1, "xzy"]).should eq %q{(1, 'xzy')} }
      it { Norm.escape_literal(Norm::Query.raw("\n\"'%")).should eq "\n\"'%" }
    end
  end

  describe ".query" do
    subject { Norm.query(:empty) }
    it { should be_an_instance_of Norm::Query }
    it { should be_frozen }
  end

  describe ".transaction" do
    context "empty" do
      before { PG::Connection.any_instance.should_receive(:exec).
                   with("BEGIN") }
      before { PG::Connection.any_instance.should_receive(:exec).
                   with("COMMIT") }
      it { Norm.transaction {} }
    end

    context "success" do
      before { Norm.should_receive(:sql).with("BEGIN") }
      before { Norm.should_receive(:sql).with(:some_sql).and_return :ok }
      before { Norm.should_receive(:sql).with("COMMIT") }
      it { Norm.transaction { Norm.sql(:some_sql) }.
               should eq :ok }
    end

    context "failure" do
      before { Norm.should_receive(:sql).with("BEGIN") }
      before { Norm.should_receive(:sql).with(:some_sql).
                   and_raise(Exception.new) }
      before { Norm.should_receive(:sql).with("ROLLBACK") }
      it { expect { Norm.transaction { Norm.sql(:some_sql) }
                  }.to raise_exception }
    end
  end

  describe ".normalize_result" do
    before { Norm.should_receive(:convert_type).
                 with("y", "zzz").and_return("q") }
    it { Norm.normalize_result({"x" => "y"}, {:x => "zzz"}).
             should eq({:x => "q"}) }
  end

  describe ".convert_type" do
    context "integers" do
      it { Norm.convert_type("42", "integer").should eq 42 }
    end

    context "character" do
      it { Norm.convert_type("blah", "character varying").
               should eq "blah" }

      it { Norm.convert_type("blah", "character varying(200)").
               should eq "blah" }
    end
  end
end

# vim: set sw=2 cc=80 et:
