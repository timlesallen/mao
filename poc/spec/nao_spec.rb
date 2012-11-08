require 'spec_helper'

describe Nao do
  before { `psql nao_testing -f #{relative_to_spec("fixture.sql")}` }
  before { Nao.connect! }

  describe ".query" do
    subject { Nao.query(:empty) }
    it { should be_an_instance_of Nao::Query }
  end

  describe Nao::Query do
    let(:empty) { Nao.query(:empty) }
    let(:one) { Nao.query(:one) }

    describe ".first" do
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
end
