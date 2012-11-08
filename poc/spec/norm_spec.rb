require 'spec_helper'

describe Norm do
  before { `psql nao_testing -f #{relative_to_spec("fixture.sql")}` }
  before { Norm.connect! }

  describe ".query" do
    subject { Norm.query(:empty) }
    it { should be_an_instance_of Norm::Query }
  end

  describe Norm::Query do
    let(:empty) { Norm.query(:empty) }
    let(:one) { Norm.query(:one) }

    describe "#first" do
      context "no results" do
        it { empty.first.should be_nil }
      end

      context "some results" do
        subject { one.first }

        it { should be_an_instance_of Hash }
        it { should eq({:id => 42, :value => "Hello, Dave."}) }
      end
    end
  end

  describe ".format_result" do
    let(:col_types) { {"korea" => "boolean",
                       "japan" => "numeric(10,2)",
                       "china" => "text"} }

    before { Norm.should_receive(:normalize_result).with(:result, col_types) }

    it do
      Norm.execute("SELECT * FROM #{Norm.quote_table("typey")}") do |pg_result|
        Norm.format_result(:result, pg_result)
      end
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
