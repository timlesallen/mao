require 'spec_helper'

describe Norm::Query do
  before { prepare_spec }

  let(:empty) { Norm.query(:empty) }
  let(:one) { Norm.query(:one) }

  describe "#execute!" do
    context "no results" do
      it { empty.execute!.should eq [] }
    end

    context "some results" do
      subject { one.execute! }

      it { should be_an_instance_of Array }
      it { should have(1).item }
      its([0]) { should eq({:id => 42, :value => "Hello, Dave."}) }
    end
  end
end

# vim: set sw=2 et:
