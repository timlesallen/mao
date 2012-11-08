require 'spec_helper'

describe Norm::Query do
  before { prepare_spec }

  let(:empty) { Norm.query(:empty) }
  let(:one) { Norm.query(:one) }
  let(:some) { Norm.query(:some) }

  describe ".new" do
    subject { Norm::Query.new(double("conn"), "table", {}) }

    its(:table) { should be_frozen }
    its(:options) { should be_frozen }
  end

  describe "#with_options" do
    subject { one.with_options(:blah => 99) }

    its(:conn) { should be one.conn }
    its(:table) { should be one.table }
    its(:options) { should eq({:blah => 99}) }
  end

  describe "#limit" do
    subject { some.limit(2) }

    its(:options) { should include(:limit => 2) }
    its(:sql) { should eq 'SELECT * FROM "some" LIMIT 2' }

    context "invalid argument" do
      it { expect { some.limit("2")
                  }.to raise_exception(ArgumentError) }

      it { expect { some.limit(false)
                  }.to raise_exception(ArgumentError) }
    end
  end

  describe "#only" do
    subject { some.only(["x", "Y"], "z") }

    its(:options) { should include(:only => %w(x Y z)) }
    its(:sql) { should eq 'SELECT "x", "Y", "z" FROM "some"' }

    context "invalid argument" do
      it { expect { some.only(42)
                  }.to raise_exception(ArgumentError) }

      it { expect { some.only(nil)
                  }.to raise_exception(ArgumentError) }
    end
  end

  describe "#where" do
    subject { some.where { (id == 1).or(id > 10_000) } }
    
    its(:options) do
      should include(:where => [:Binary,
                                'OR',
                                [:Binary, '=', [:Column, :id], "'1'"],
                                [:Binary, '>', [:Column, :id], "'10000'"]])
    end

    its(:sql) { should eq 'SELECT * FROM "some" WHERE ' \
                          '(("id" = \'1\') OR ("id" > \'10000\'))' }

    context "non-extant column" do
      pending "it doesn't do table checks yet" do
        it { expect { some.where { non_extant_column == 42 }
                    }.to raise_exception(ArgumentError) }
      end
    end
  end

  describe "#execute!" do
    describe "use of #sql" do
      # HACK: construct empty manually, otherwise it's frozen and we can't use
      # #should_receive.
      let(:empty) { Norm::Query.new(Norm.instance_variable_get("@conn"),
                                    "empty") }
      let(:empty_sql) { double("empty_sql") }
      before { empty.should_receive(:sql).and_return(empty_sql) }
      before { PG::Connection.any_instance.should_receive(:exec).
                   with(empty_sql).and_return(:ok) }
      it { empty.execute!.should eq :ok }
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
