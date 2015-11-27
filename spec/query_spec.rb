# encoding: utf-8
require 'spec_helper'

describe Mao::Query do
  before { prepare_spec }

  let(:empty) { Mao.query(:empty) }
  let(:one) { Mao.query(:one) }
  let(:some) { Mao.query(:some) }
  let(:typey) { Mao.query(:typey) }
  let(:autoid) { Mao.query(:autoid) }
  let(:times) { Mao.query(:times) }

  describe ".new" do
    subject { Mao::Query.new(:table, {}, {}) }

    describe '#table' do
      subject { super().table }
      it { is_expected.to be_an_instance_of Symbol }
    end

    describe '#options' do
      subject { super().options }
      it { is_expected.to be_frozen }
    end

    describe '#col_types' do
      subject { super().col_types }
      it { is_expected.to be_frozen }
    end

    context "no such table" do
      it { expect { Mao::Query.new("nonextant")
                  }.to raise_exception(ArgumentError) }
    end
  end

  describe "#with_options" do
    subject { one.with_options(:blah => 99) }

    describe '#table' do
      subject { super().table }
      it { is_expected.to be one.table }
    end

    describe '#options' do
      subject { super().options }
      it { is_expected.to eq({:blah => 99}) }
    end
  end

  describe "#limit" do
    subject { some.limit(2) }

    describe '#options' do
      subject { super().options }
      it { is_expected.to include(:limit => 2) }
    end

    describe '#sql' do
      subject { super().sql }
      it { is_expected.to eq 'SELECT * FROM "some" LIMIT 2' }
    end

    context "invalid argument" do
      it { expect { some.limit("2")
                  }.to raise_exception(ArgumentError) }

      it { expect { some.limit(false)
                  }.to raise_exception(ArgumentError) }
    end
  end

  describe "#order" do
    let(:asc) { some.order(:id, :asc) }
    it { expect(asc.options).to include(:order => [:id, 'ASC']) }
    it { expect(asc.sql).to eq 'SELECT * FROM "some" ORDER BY "id" ASC' }

    let(:desc) { one.order(:value, :desc) }
    it { expect(desc.options).to include(:order => [:value, 'DESC']) }
    it { expect(desc.sql).to eq 'SELECT * FROM "one" ORDER BY "value" DESC' }

    it { expect { one.order(:huh, :asc) }.to raise_exception(ArgumentError) }
    it { expect { one.order(:value) }.to raise_exception(ArgumentError) }
    it { expect { one.order(:id, 'ASC') }.to raise_exception(ArgumentError) }
    it { expect { one.order(:id, :xyz) }.to raise_exception(ArgumentError) }
  end

  describe "#only" do
    subject { some.only(:id, [:value]) }

    describe '#options' do
      subject { super().options }
      it { is_expected.to include(:only => [:id, :value]) }
    end

    describe '#sql' do
      subject { super().sql }
      it { is_expected.to eq 'SELECT "id", "value" FROM "some"' }
    end

    context "invalid argument" do
      it { expect { some.only(42)
                  }.to raise_exception(ArgumentError) }

      it { expect { some.only(nil)
                  }.to raise_exception(ArgumentError) }

      it { expect { some.only("id")
                  }.to raise_exception(ArgumentError) }

      it { expect { some.only(:j)
                  }.to raise_exception(ArgumentError) }
    end

    context "with #join" do
      subject { some.join(:one) { one.value == some.value }.
                    only(:one => [:id]) }

      describe '#options' do
        subject { super().options }
        it { is_expected.to include(:only => {:one => [:id]}) }
      end

      describe '#sql' do
        subject { super().sql }
        it { is_expected.to eq 'SELECT "one"."id" "c3" ' +
                            'FROM "some" ' +
                            'INNER JOIN "one" ' +
                            'ON ("one"."value" = "some"."value")' }
      end
      describe '#select!' do
        subject { super().select! }
        it { is_expected.to eq [{:one => {:id => 42}}] }
      end

      context "before #join" do
        it { expect { some.only(:some => [:id])
                    }.to raise_exception(ArgumentError) }
      end

      context "poor arguments" do
        it { expect { some.join(:one) { one.value }.only(:some => :id)
                    }.to raise_exception(ArgumentError) }
      end
    end
  end

  describe "#returning" do
    subject { some.returning([:id], :value).
                  with_options(:insert => [{:value => "q"}]) }

    describe '#options' do
      subject { super().options }
      it { is_expected.to include(:returning => [:id, :value]) }
    end

    describe '#sql' do
      subject { super().sql }
      it { is_expected.to eq 'INSERT INTO "some" ("value") ' +
                          'VALUES (\'q\') RETURNING "id", "value"' }
    end

    context "invalid argument" do
      it { expect { some.returning(42)
                  }.to raise_exception(ArgumentError) }

      it { expect { some.returning(nil)
                  }.to raise_exception(ArgumentError) }

      it { expect { some.returning("id")
                  }.to raise_exception(ArgumentError) }

      it { expect { some.returning("j")
                  }.to raise_exception(ArgumentError) }
    end
  end

  describe "#where" do
    subject { some.where { (id == 1).or(id > 10_000) } }
    
    describe '#options' do
      subject { super().options }
      it do
      is_expected.to include(:where => [:Binary,
                                'OR',
                                [:Binary, '=', [:Column, :id], "1"],
                                [:Binary, '>', [:Column, :id], "10000"]])
    end
    end

    describe '#sql' do
      subject { super().sql }
      it { is_expected.to eq 'SELECT * FROM "some" WHERE ' \
                          '(("id" = 1) OR ("id" > 10000))' }
    end

    context "non-extant column" do
      it { expect { some.where { non_extant_column == 42 }
                  }.to raise_exception(ArgumentError) }
    end

    context "with #join" do
      subject { some.join(:one) { one.value == some.value }.
                    where { one.id == 42 } }

      describe '#options' do
        subject { super().options }
        it { is_expected.to include(:where => [:Binary,
                                                '=',
                                                [:Column, :one, :id],
                                                "42"]) }
      end
      describe '#sql' do
        subject { super().sql }
        it { is_expected.to eq 'SELECT "some"."id" "c1", ' +
                            '"some"."value" "c2", ' +
                            '"one"."id" "c3", ' +
                            '"one"."value" "c4" ' +
                            'FROM "some" ' +
                            'INNER JOIN "one" ' +
                            'ON ("one"."value" = "some"."value") ' +
                            'WHERE ("one"."id" = 42)' }
      end

      describe '#select!' do
        subject { super().select! }
        it { is_expected.to eq(
                          [{:some => {:id => 3, :value => "你好, Dave."},
                            :one => {:id => 42, :value => "你好, Dave."}}]) }
      end
    end

    context "with time values" do
      it { expect(times.select_first!).to eq(
               {:id => 1, :time => Time.new(2012, 11, 10, 19, 45, 0, 0)}) }

      it { expect(times.where { time == Time.new(2012, 11, 11, 6, 45, 0, 11 * 3600) }.
               select!.length).to eq 1 }
      it { expect(times.where { time == Time.new(2012, 11, 10, 19, 45, 0, 0) }.
               select!.length).to eq 1 }
      it { expect(times.where { time == "2012-11-10 19:45:00" }.
               select!.length).to eq 1 }
      it { expect(times.where { time == "2012-11-10 19:45:00 Z" }.
               select!.length).to eq 1 }
      it { expect(times.where { time == "2012-11-10 19:45:00 +00" }.
               select!.length).to eq 1 }
      it { expect(times.where { time == "2012-11-10 19:45:00 +00:00" }.
               select!.length).to eq 1 }
      it { expect(times.where { time == "2012-11-10 19:45:00 -00" }.
               select!.length).to eq 1 }
      it { expect(times.where { time == "2012-11-10 19:45:00 -00:00" }.
               select!.length).to eq 1 }

      it { expect(times.where { time < Time.new(2012, 11, 11, 6, 45, 0, 11 * 3600) }.
               select!.length).to eq 0 }
      context "surprising results" do
        # Timestamps are IGNORED for comparisons with "timestamp without time
        # zone".  See:
        # http://postgresql.org/docs/9.1/static/datatype-datetime.html#AEN5714
        it { expect(times.where { time < "2012-11-11 6:45:00 +11" }.
                 select!.length).to eq 1 }
        it { expect(times.where { time < "2012-11-11 6:45:00 +1100" }.
                 select!.length).to eq 1 }
        it { expect(times.where { time < "2012-11-11 6:45:00 +11:00" }.
                 select!.length).to eq 1 }
      end
      it { expect(times.where { time <= Time.new(2012, 11, 11, 6, 45, 0, 11 * 3600) }.
               select!.length).to eq 1 }
      it { expect(times.where { time <= "2012-11-11 6:45:00 +11" }.
               select!.length).to eq 1 }
      it { expect(times.where { time <= "2012-11-11 6:45:00 +1100" }.
               select!.length).to eq 1 }
      it { expect(times.where { time <= "2012-11-11 6:45:00 +11:00" }.
               select!.length).to eq 1 }
    end
  end

  describe "#join" do
    subject { some.join(:one) { one.value == some.value } }

    describe '#options' do
      subject { super().options }
      it do
      is_expected.to include(:join => [:one,
                               [:Binary,
                                '=',
                                [:Column, :one, :value],
                                [:Column, :some, :value]]])
    end
    end

    describe '#sql' do
      subject { super().sql }
      it { is_expected.to eq(
      'SELECT ' +
      '"some"."id" "c1", ' +
      '"some"."value" "c2", ' +
      '"one"."id" "c3", ' +
      '"one"."value" "c4" ' +
      'FROM "some" ' +
      'INNER JOIN "one" ' +
      'ON ("one"."value" = "some"."value")') }
    end

    describe '#select!' do
      subject { super().select! }
      it { is_expected.to eq [{:some => {:id => 3,
                                          :value => "你好, Dave."},
                                :one => {:id => 42,
                                          :value => "你好, Dave."}}] }
    end

    context "simple Hash joins" do
      subject { some.join({:one => {:value => :id}}) }

      describe '#options' do
        subject { super().options }
        it do
        is_expected.to include(:join => [:one,
                                 [:Binary,
                                  '=',
                                  [:Column, :some, :value],
                                  [:Column, :one, :id]]])
      end
      end
    end
  end

  describe "#select!" do
    context "use of #sql" do
      # HACK: construct empty manually, otherwise it'll try to look up column
      # info and ruin our assertions.
      let(:empty) { Mao::Query.new("empty",
                                    {},
                                    {}) }
      let(:empty_sure) { double("empty_sure") }
      let(:empty_sql) { double("empty_sql") }
      before { expect(empty).to receive(:with_options).
                   with(:update => nil).
                   and_return(empty_sure) }
      before { expect(empty_sure).to receive(:sql).
                   and_return(empty_sql) }
      before { expect_any_instance_of(PG::Connection).to receive(:exec).
                   with(empty_sql).and_return(:ok) }
      it { expect(empty.select!).to eq :ok }
    end

    context "no results" do
      it { expect(empty.select!).to eq [] }
    end

    context "one result" do
      subject { one.select! }

      it { is_expected.to be_an_instance_of Array }
      it 'has 1 item' do
        expect(subject.size).to eq(1)
      end

      describe '[0]' do
        subject { super()[0] }
        it { is_expected.to eq({:id => 42, :value => "你好, Dave."}) }
      end
    end

    context "some results" do
      subject { some.select! }

      it { is_expected.to be_an_instance_of Array }
      it 'has 3 items' do
        expect(subject.size).to eq(3)
      end

      describe '[0]' do
        subject { super()[0] }
        it { is_expected.to eq({:id => 1, :value => "Bah"}) }
      end

      describe '[1]' do
        subject { super()[1] }
        it { is_expected.to eq({:id => 2, :value => "Hah"}) }
      end

      describe '[2]' do
        subject { super()[2] }
        it { is_expected.to eq({:id => 3, :value => "你好, Dave."}) }
      end
    end

    context "various types" do
      subject { typey.select! }

      it 'has 2 items' do
        expect(subject.size).to eq(2)
      end

      describe '[0]' do
        subject { super()[0] }
        it { is_expected.to eq(
        {:korea => true,
         :japan => BigDecimal.new("1234567890123456.789"),
         :china => "WHAT\x00".force_encoding(Encoding::ASCII_8BIT)}) }
      end
      describe '[1]' do
        subject { super()[1] }
        it { is_expected.to eq(
        {:korea => false,
         :japan => BigDecimal.new("-1234567890123456.789"),
         :china => "HUH\x01\x02".force_encoding(Encoding::ASCII_8BIT)}) }
      end
    end
  end

  describe "#select_first!" do
    # HACK: construct empty manually, otherwise it'll try to look up column
    # info and ruin our assertions.
    let(:empty) { Mao::Query.new("empty",
                                  {},
                                  {}) }
    before { expect(empty).to receive(:limit).with(1).and_return(empty) }
    before { expect(empty).to receive(:select!).and_return([:ok]) }
    it { expect(empty.select_first!).to eq :ok }
  end

  describe "#update!" do
    context "use of #sql" do
      let(:empty) { Mao::Query.new("empty",
                                    {},
                                    {}) }
      let(:empty_update) { double("empty_update") }
      let(:empty_sql) { double("empty_sql") }
      before { expect(empty).to receive(:with_options).
                   with(:update => {:x => :y}).
                   and_return(empty_update) }
      before { expect(empty_update).to receive(:sql).and_return(empty_sql) }
      before { expect_any_instance_of(PG::Connection).to receive(:exec).
                   with(empty_sql).and_return(:ok) }
      it { expect(empty.update!(:x => :y)).to eq :ok }
    end

    context "#sql result" do
      subject { empty.with_options(:update => {:id => 44}).sql }
      it { is_expected.to eq 'UPDATE "empty" SET "id" = 44' }
    end

    context "no matches" do
      it { expect(empty.update!(:value => "y")).to eq 0 }
    end

    context "no such column" do
      it { expect { empty.update!(:x => "y")
                  }.to raise_exception(ArgumentError, /is not a column/) }
    end

    context "some matches" do
      it { expect(some.where { id <= 2 }.update!(:value => 'Meh')).to eq 2 }
    end
  end

  describe "#insert!" do
    context "use of #sql" do
      let(:empty) { Mao::Query.new("empty",
                                    {},
                                    {}) }
      let(:empty_insert) { double("empty_insert") }
      let(:empty_sql) { double("empty_sql") }
      before { expect(empty).to receive(:with_options).
                   with(:insert => [{:x => :y}]).
                   and_return(empty_insert) }
      before { expect(empty_insert).to receive(:sql).and_return(empty_sql) }
      before { expect_any_instance_of(PG::Connection).to receive(:exec).
                   with(empty_sql).and_return(:ok) }
      it { expect(empty.insert!([:x => :y])).to eq :ok }
    end

    context "#sql result" do
      context "all columns alike" do
        subject { empty.with_options(
                      :insert => [{:id => 44}, {:id => 38}]).sql }
        it { is_expected.to eq 'INSERT INTO "empty" ("id") VALUES (44), (38)' }
      end

      context "not all columns alike" do
        subject { empty.with_options(
                      :insert => [{:id => 1}, {:value => 'z', :id => 2}]).sql }
        it { is_expected.to eq 'INSERT INTO "empty" ("id", "value") ' +
                       'VALUES (1, DEFAULT), (2, \'z\')' }
      end
    end

    context "result" do
      context "number of rows" do
        it { expect(autoid.insert!(:value => "quox")).to eq 1 }
        it { expect(autoid.insert!({:value => "lol"}, {:value => "x"})).to eq 2 }
      end

      context "#returning" do
        it do
          expect(autoid.returning(:id).insert!(:value => "nanana")).
              to eq([{:id => 1}])
          expect(autoid.returning(:id).insert!(:value => "ha")).
              to eq([{:id => 2}])
          expect(autoid.returning(:id).insert!(:value => "bah")).
              to eq([{:id => 3}])
          expect(autoid.returning(:id).insert!({:value => "a"}, {:value => "b"})).
              to eq([{:id => 4}, {:id => 5}])
        end
      end
    end
  end

  describe "reconnection" do
    it do
      expect(Mao.query(:one).select!).to be_an_instance_of Array
      skip
    end
  end
end

# vim: set sw=2 cc=80 et:
