require 'spec_helper'

describe Norm::Query do
  before { prepare_spec }

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

