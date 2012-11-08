require 'spec_helper'

describe Norm do
  before { prepare_spec }

  describe ".connect!" do
    before { PG.should_receive(:connect) }
    before { Norm.disconnect! rescue false }
    it { Norm.connect! }
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
    before { PG::Connection.any_instance.should_receive(:quote_ident).
                 with("table").and_return(%q{"table"}) }
    it { Norm.quote_ident("table").should eq %q{"table"} }
  end

  describe ".escape_literal" do
    describe "verify pass-thru" do
      before { PG::Connection.any_instance.should_receive(:escape_literal).
                   with("table").and_return(%q{'table'}) }
      it { Norm.escape_literal("table").should eq %q{'table'} }
    end

    describe "actual values" do
      it { Norm.escape_literal("table").should eq %q{'table'} }
    end
  end

  describe ".query" do
    subject { Norm.query(:empty) }
    it { should be_an_instance_of Norm::Query }
    it { should be_frozen }
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
