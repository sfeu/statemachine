module Statemachine

  class Parallelstate < Superstate

    attr_accessor :parallel_statemachines, :id, :entry_action, :exit_action
    attr_reader :startstate_ids

    def initialize(id, superstate, statemachine)
      super(id, superstate, statemachine)
      @parallel_statemachines=[]
      @startstate_ids=[]
      @transitions = {}
      @spontaneous_transitions = []
    end

    def add(transition)
      if transition.event == nil
        @spontaneous_transitions.push(transition)
      else
        @transitions[transition.event] = transition
      end
    end
#    def startstate_id= id
#      if @parallel_statemachines.size>0
#        @startstate_ids[@parallel_statemachines.size-1]= id
#      end
#    end
#
#    def startstate_id
#      if (@parallel_statemachines.size>0 and @parallel_statemachines.size==@startstate_ids.size)
#        return true
#      end
#      nil
#    end

    def context= c
      @parallel_statemachines.each do |s|
        s.context=c
      end
    end

    def activate(terminal_state = nil)
      @parallel_statemachines.each do |s|
         next if terminal_state and s.has_state(terminal_state)
   #     @statemachine.activation.call(s.state,self.abstract_states+s.abstract_states,s.state) if @statemachine.activation
      end

    end

    def add_statemachine(statemachine)
      statemachine.is_parallel=self
      @parallel_statemachines.push(statemachine)
      statemachine.context = @statemachine.context
      @startstate_ids << @startstate_id
      @startstate_id = nil
    end

    def get_statemachine_with(id)
      @parallel_statemachines.each do |s|
        return s if s.has_state(id)
      end
    end

    def non_default_transition_for(event,check_superstates=true)
      transition = @transitions[event]
      return transition if transition

      transition = transition_for(event,check_superstates)

      transition = @superstate.non_default_transition_for(event) if check_superstates and @superstate and not transition
      return transition
    end

    def In(id)
      @parallel_statemachines.each do |s|
        return true if s.In(id.to_sym)
      end
      return false
    end

    def state= id
      @parallel_statemachines.each do |s|
        if s.has_state(id)
          s.state=id
          return true
        end
      end
      return false
    end

    def has_state(id)
      @parallel_statemachines.each do |s|
        if s.has_state(id)
          return true
        end
      end
      return false
    end

    def get_state(id)
#      if state = @statemachine.get_state(id)
#        return state
#      end
      @parallel_statemachines.each do |s|
        if state = s.get_state(id)
          return state
        end
      end
      return nil
    end

    def process_event(event, *args)
      exceptions = []
      result = false
      #  TODO fix needed: respond_to checks superstates lying out of the parallel state as well, in case an event is
      # defined outside the parallel statemachine it gets processed twice!

      @parallel_statemachines.each_with_index do |s,i|
        if s.respond_to? event
          s.process_event(event,*args)
          result = true
        end
      end
      result
    end

    # Resets all of the statemachines back to theirs starting state.
    def reset
      @parallel_statemachines.each_with_index do |s,i|
        s.reset(@startstate_ids[i])
      end
    end

    def concrete?
      return true
    end

    def startstate
      return @statemachine.get_state(@startstate_id)
    end

    def resolve_startstate
      return self
    end

    def substate_exiting(substate)
      @history_id = substate.id
    end

    def add_substates(*substate_ids)
      do_substate_adding(substate_ids)
    end

    def default_history=(state_id)
      @history_id = @default_history_id = state_id
    end

    def states
      result =[]
      @parallel_statemachines.each  do |s|
        state = s.state
        r,p = s.belongs_to_parallel(state)
        if r
          result += p.states
        else
          result << state
        end
      end
      result
    end

    def transition_for(event,check_superstates=true)
      @parallel_statemachines.each do |s|
        transition = s.get_state(s.state).non_default_transition_for(event,false)
        transition = s.get_state(s.state).default_transition if not transition
        return transition if transition
      end
      return @superstate.transition_for(event,check_superstates) if (@superstate and check_superstates and @superstate!=self)

      #super.transition_for(event)
    end

    def enter(args=[])
      @statemachine.state = self
      @statemachine.trace("\tentering #{self}")

      if @entry_action != nil
        messenger = self.statemachine.messenger
        message_queue = self.statemachine.message_queue
        @statemachine.invoke_action(@entry_action, args, "entry action for #{self}", messenger, message_queue)
      end

      @parallel_statemachines.each_with_index do |s,i|
        s.activation = @statemachine.activation
        s.reset(@startstate_ids[i]) if not s.state
        s.get_state(@startstate_ids[i]).enter(args)
      end
    end

    def exit(args)
      @statemachine.trace("\texiting #{self}")

      if @exit_action != nil
        messenger = self.statemachine.messenger
        message_queue = self.statemachine.message_queue
        @statemachine.invoke_action(@exit_action, args, "exit action for #{self}", messenger, message_queue)
        @superstate.substate_exiting(self) if @superstate
      end

      @parallel_statemachines.each_with_index do |s,i|
        s.get_state(@state).exit(args)
      end
    end

    def to_s
      return "'#{id}' parallel"
    end

    def abstract_states
      abstract_states=[]

      if (@superstate)
        abstract_states=@superstate.abstract_states
      end

      abstract_states += [@id]

      @parallel_statemachines.each do |s|
        abstract_states += s.abstract_states + []
      end
      abstract_states.uniq
    end
    def is_parallel
      true
    end
  end

end
