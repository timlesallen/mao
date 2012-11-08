require 'spec_helper'

describe Norm do
  before { prepare_spec }

  describe ".connect!" do
    before { PG.should_receive(:connect) }
    it { Norm.connect! }
  end

  describe ".sql" do
    before { PG::Connection.any_instance.should_receive(:exec).with(:x).and_return(:y) }
    it { Norm.sql(:x).should eq :y }
  end

  describe ".quote_table" do
    before { PG::Connection.should_receive(:quote_ident).with("table").and_return(%Q{"table"}) }
    it { Norm.quote_table("table").should eq %Q{"table"} }
  end

  describe ".query" do
    subject { Norm.query(:empty) }
    it { should be_an_instance_of Norm::Query }
  end

  describe ".format_results" do
    let(:col_types) { {"korea" => "boolean",
                       "japan" => "numeric(10,2)",
                       "china" => "text"} }

    before { Norm.should_receive(:normalize_result).with(:result, col_types).and_return(:moo) }

    it do
      Norm.sql("SELECT * FROM #{Norm.quote_table("typey")}") do |pg_result|
        Norm.format_results([:result], pg_result)
      end.should eq [:moo]
    end
  end

  describe ".normalize_result" do
    before { Norm.should_receive(:convert_type).with("y", "zzz").and_return("q") }
    it { Norm.normalize_result({"x" => "y"}, {"x" => "zzz"}).should eq({:x => "q"}) }
  end

  describe ".convert_type" do
    context "integers" do
      it { Norm.convert_type("42", "integer").should eq 42 }
    end

    context "character" do
      it { Norm.convert_type("blah", "character varying(200)").should eq "blah" }
    end
  end
end
