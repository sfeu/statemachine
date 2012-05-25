require File.dirname(__FILE__) + '/spec_helper'

describe "Transition Calculating Exits and Entries" do

  before(:each) do
    @transition = Statemachine::Transition.new(nil, nil, nil, nil, true)
  end
  
  it "to nil" do
    @a = Statemachine::State.new("a", nil, nil)
    exits, entries = @transition.exits_and_entries(@a, nil)
    exits.to_s.should eql([@a].to_s)
    entries.to_s.should eql([].to_s)
    entries.length.should equal(0)
  end
  
  it "to itself" do
    @a = Statemachine::State.new("a", nil, nil)
    exits, entries = @transition.exits_and_entries(@a, @a)
    exits.to_s.should eql([@a].to_s)
    entries.to_s.should eql([@a].to_s)
  end

  it "to friend" do
    @a = Statemachine::State.new("a", nil, nil)
    @b = Statemachine::State.new("b", nil, nil)
    exits, entries = @transition.exits_and_entries(@a, @b)
    exits.to_s.should eql([@a].to_s)
    entries.to_s.should eql([@b].to_s)
  end

  it "to parent" do
    @b = Statemachine::State.new("b", nil, nil)
    @a = Statemachine::State.new("a", @b, nil)
    exits, entries = @transition.exits_and_entries(@a, @b)
    exits.to_s.should eql([@a, @b].to_s)
    entries.to_s.should eql([@b].to_s)
  end

  it "to uncle" do
    @b = Statemachine::State.new("b", nil, nil)
    @a = Statemachine::State.new("a", @b, nil)
    @c = Statemachine::State.new("c", nil, nil)
    exits, entries = @transition.exits_and_entries(@a, @c)
    exits.to_s.should eql([@a, @b].to_s)
    entries.to_s.should eql([@c].to_s)
  end

  it "to cousin" do
    @b = Statemachine::State.new("b", nil, nil)
    @d = Statemachine::State.new("d", nil, nil)
    @a = Statemachine::State.new("a", @b, nil)
    @c = Statemachine::State.new("c", @d, nil)
    exits, entries = @transition.exits_and_entries(@a, @c)
    exits.to_s.should eql([@a, @b].to_s)
    entries.to_s.should eql([@d, @c].to_s)
  end
  
  it "to nephew" do
    @b = Statemachine::State.new("b", nil, nil)
    @c = Statemachine::State.new("c", nil, nil)
    @a = Statemachine::State.new("a", @b, nil)
    exits, entries = @transition.exits_and_entries(@c, @a)
    exits.to_s.should eql([@c].to_s)
    entries.to_s.should eql([@b,@a].to_s)
  end

  it "to sister" do
    @c = Statemachine::State.new("c", nil, nil)
    @a = Statemachine::State.new("a", @c, nil)
    @b = Statemachine::State.new("b", @c, nil)
    exits, entries = @transition.exits_and_entries(@a, @b)
    exits.to_s.should eql([@a].to_s)
    entries.to_s.should eql([@b].to_s)
  end
  
  it "to second cousin" do
    @c = Statemachine::State.new("c", nil, nil)
    @b = Statemachine::State.new("b", @c, nil)
    @a = Statemachine::State.new("a", @b, nil)
    @e = Statemachine::State.new("e", @c, nil)
    @d = Statemachine::State.new("d", @e, nil)
    exits, entries = @transition.exits_and_entries(@a, @d)
    exits.to_s.should eql([@a, @b].to_s)
    entries.to_s.should eql([@e, @d].to_s)
  end

  it "to grandparent" do
    @c = Statemachine::State.new("c", nil, nil)
    @b = Statemachine::State.new("b", @c, nil)
    @a = Statemachine::State.new("a", @b, nil)
    exits, entries = @transition.exits_and_entries(@a, @c)
    exits.to_s.should eql([@a, @b, @c].to_s)
    entries.to_s.should eql([@c].to_s)
  end

  it "to parent's grandchild" do
    @c = Statemachine::State.new("c", nil, nil)
    @b = Statemachine::State.new("b", @c, nil)
    @a = Statemachine::State.new("a", @b, nil) 
    @d = Statemachine::State.new("d", @c, nil)
    exits, entries = @transition.exits_and_entries(@d, @a)
    exits.to_s.should eql([@d].to_s)
    entries.to_s.should eql([@b, @a].to_s)
  end

end

describe "Transitions without events" do
  before(:each) do
    @log = ""
    @sm = Statemachine.build do
      state :off do
        on_entry Proc.new {puts "entering off"}
        on_exit Proc.new {puts "exiting off"}
        event :toggle, :on, Proc.new { @log += "on" }
        event nil, :done, nil, Proc.new {@log == "onoff"}
      end
      trans :on, :toggle, :off, Proc.new { @log += "off" }
    end
    @sm.context = self
  end

  it "should be done" do
     @sm.toggle
     @sm.state.should == :on
     @sm.toggle
     @sm.state.should == :done
  end
end

describe "Transitions with same events but different conditions" do
  before(:each) do
    @power = true
    @sm = Statemachine.build do
      trans :off, :toggle, :on, nil, "@power"
      trans :off, :toggle, :no_power, nil, "not @power"
      trans :on, :toggle, :off
    end
    @sm.context = self
  end

  it "should be on" do
    @sm.state.should == :off
    @sm.toggle
    @sm.state.should == :on

  end
end

