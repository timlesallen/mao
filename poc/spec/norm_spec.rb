require 'spec_helper'

describe Norm do
  around {|example| prepare_spec(example) }

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
    before { PG::Connection.should_receive(:quote_ident).
                 with("table").and_return(%Q{"table"}) }
    it { Norm.quote_ident("table").should eq %Q{"table"} }
  end

  describe ".query" do
    subject { Norm.query(:empty) }
    it { should be_an_instance_of Norm::Query }
    it { should be_frozen }
  end

  describe ".format_results" do
    let(:col_types) { {"korea" => "boolean",
                       "japan" => "numeric(10,2)",
                       "china" => "text"} }

    before { Norm.should_receive(:normalize_result).
                 with(:result, col_types).and_return(:moo) }

    it do
      Norm.sql("SELECT * FROM #{Norm.quote_ident("typey")}") do |pg_result|
        Norm.format_results([:result], pg_result)
      end.should eq [:moo]
    end
  end

  describe ".normalize_result" do
    before { Norm.should_receive(:convert_type).
                 with("y", "zzz").and_return("q") }
    it { Norm.normalize_result({"x" => "y"}, {"x" => "zzz"}).
             should eq({:x => "q"}) }
  end

  describe ".convert_type" do
    context "integers" do
      it { Norm.convert_type("42", "integer").should eq 42 }
    end

    context "character" do
      it { Norm.convert_type("blah", "character varying(200)").
               should eq "blah" }
    end
  end
end

# vim: set sw=2 cc=80 et:
