require 'spec_helper'

describe Norm::Query do
  before { prepare_spec }

  let(:empty) { Norm.query(:empty) }
  let(:one) { Norm.query(:one) }
  let(:some) { Norm.query(:some) }

  describe "#limit" do
    subject { some.limit(2) }

    its(:options) { should include(:limit => 2) }
    its(:sql) { should eq 'SELECT * FROM "some" LIMIT 2' }
  end

  describe "#execute!" do
    describe "use of #sql" do
      let(:empty_sql) { double("empty_sql") }
      before { empty.should_receive(:sql).and_return(empty_sql) }
      before { PG::Connection.any_instance.should_receive(:exec).
                   with(empty_sql).and_return(:ok) }
      it { empty.execute!().should eq :ok }
    end

    context "no results" do
      it { empty.execute!.should eq [] }
    end

    context "one result" do
      subject { one.execute! }

      it { should be_an_instance_of Array }
      it { should have(1).item }
      its([0]) { should eq({:id => 42, :value => "Hello, Dave."}) }
    end

    context "some results" do
      subject { some.execute! }

      it { should be_an_instance_of Array }
      it { should have(3).items }

      its([0]) { should eq({:id => 1, :value => "Bah"}) }
      its([1]) { should eq({:id => 2, :value => "Hah"}) }
      its([2]) { should eq({:id => 3, :value => "Pah"}) }
    end
  end
end

# vim: set sw=2 cc=80 et:
