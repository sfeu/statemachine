require 'statemachine/generate/util'
require 'statemachine/generate/src_builder'

module Statemachine
  class Statemachine

    attr_reader :states

    def to_java(options = {})
      generator = Generate::Java::JavaStatemachine.new(self, options)
      generator.generate!
    end

  end

  module Generate
    module Java
      class JavaStatemachine

        include Generate::Util

        HEADER1 = "// This file was generated by the Ruby Statemachine Library (http://slagyr.github.com/statemachine)."
        HEADER2 = "// Generated at "

        def initialize(sm, options)
          @sm = sm
          @output_dir = options[:output]
          @classname = options[:name]
          @context_classname = "#{@classname}Context"
          @package = options[:package]
          raise "Please specify an output directory. (:output => 'where/you/want/your/code')" if @output_dir.nil?
          raise "Output dir '#{@output_dir}' doesn't exist." if !File.exist?(@output_dir)
          raise "Please specify a name for the statemachine. (:name => 'SomeName')" if @classname.nil?
        end

        def generate!
          explore_sm
          create_file(src_file(@classname), build_statemachine_src)
          create_file(src_file(@context_classname), build_context_src)
          say "Statemachine generated."
        end

        private ###########################################

        def explore_sm
          events = []
          actions = []
          @sm.states.values.each do |state|
            state.transitions.each do |transition|
              events << transition.event
              add_action(actions, transition.action)
            end
          end
          @event_names = events.uniq.map {|e| e.to_s.camalized(:lower)}.sort

          @sm.states.values.each do |state|
            add_action(actions, state.entry_action)
            add_action(actions, state.exit_action)
          end
          @action_names = actions.uniq.map {|e| e.to_s.camalized(:lower)}.sort

          @startstate = @sm.get_state(@sm.startstate).resolve_startstate
        end

        def add_action(actions, action)
          return if action.nil?
          raise "Actions must be symbols in order to generation Java code. (#{action})" unless action.is_a?(Symbol)
          actions << action
        end

        def build_statemachine_src
          src = begin_src
          src << "public class #{@classname}" << endl
          begin_scope(src)

          add_instance_variables(src)
          add_constructor(src)
          add_statemachine_boilerplate_code(src)
          add_event_delegation(src)
          add_statemachine_exception(src)
          add_base_state(src)
          add_state_implementations(src)

          end_scope(src)
          return src.to_s
        end

        def add_instance_variables (src)
          src << "// Instance variables" << endl
          concrete_states = @sm.states.values.reject { |state| state.id.nil? || !state.concrete? }.sort { |a, b| a.id <=> b.id }
          concrete_states.each do |state|
            name = state.id.to_s
            src << "public final State #{name.upcase} = new #{name.camalized}State(this);" << endl
          end
          superstates = @sm.states.values.reject { |state| state.concrete? }.sort { |a, b| a.id <=> b.id }
          superstates.each do |superstate|
            startstate = superstate.resolve_startstate
            src << "public final State #{superstate.id.to_s.upcase} = #{startstate.id.to_s.upcase};" << endl
          end
          src << "private State state = #{@startstate.id.to_s.upcase};" << endl
          src << endl
          src << "private #{@context_classname} context;" << endl
          src << endl
        end

        def add_constructor(src)
          src << "// Statemachine constructor" << endl
          add_method(src, nil, @classname, "#{@context_classname} context") do
            src << "this.context = context;" << endl
            entered_states = []
            entry_state = @startstate
            while entry_state != @sm.root
              entered_states << entry_state
              entry_state = entry_state.superstate
            end
            entered_states.reverse.each do |state|
              src << "context.#{state.entry_action.to_s.camalized(:lower)}();" << endl if state.entry_action
            end
          end
        end

        def add_statemachine_boilerplate_code(src)
          src << "// The following is boiler plate code standard to all statemachines" << endl
          add_one_liner(src, @context_classname, "getContext", nil, "return context")
          add_one_liner(src, "State", "getState", nil, "return state")
          add_one_liner(src, "void", "setState", "State newState", "state = newState")
        end

        def add_event_delegation(src)
          src << "// Event delegation" << endl
          @event_names.each do |event|
            add_one_liner(src, "void", event, nil, "state.#{event}()")
          end
        end

        def add_statemachine_exception(src)
          src << "// Standard exception class added to all statemachines." << endl
          src << "public static class StatemachineException extends RuntimeException" << endl
          begin_scope(src)
          src << "public StatemachineException(State state, String event)" << endl
          begin_scope(src)
          src << "super(\"Missing transition from '\" + state.getClass().getSimpleName() + \"' with the '\" + event + \"' event.\");" << endl
          end_scope(src)
          end_scope(src)
          src << endl
        end

        def add_base_state(src)
          src << "// The base state" << endl
          src << "public static abstract class State" << endl
          begin_scope(src)
          src << "protected #{@classname} statemachine;" << endl
          src << endl
          add_one_liner(src, nil, "State", "#{@classname} statemachine", "this.statemachine = statemachine")
          @event_names.each do |event|
            add_one_liner(src, "void", event, nil, "throw new StatemachineException(this, \"#{event}\")")
          end
          end_scope(src)
          src << endl
        end

        def add_state_implementations(src)
          src << "// State implementations" << endl
          @sm.states.keys.reject{|k| k.nil? }.sort.each do |state_id|
            state = @sm.states[state_id]
            state_name = state.id.to_s.camalized
            base_class = state.superstate == @sm.root ? "State" : state.superstate.id.to_s.camalized

            add_concrete_state_class(src, state, state_name, base_class) if state_id
          end
        end

        def add_concrete_state_class(src, state, state_name, base_class)
          src << "public static class #{state_name}State extends State" << endl
          src << "{" << endl
          src.indent!
          add_one_liner(src, nil, "#{state_name}State", "#{@classname} statemachine", "super(statemachine)")
          trans_aux =  state.transitions
          trans_aux.sort_by!{|t| t.event}.each do |t|
            add_state_event_handler(t, src)
          end
          src.undent!
          src << "}" << endl
          src << endl
        end

        def add_state_event_handler(transition, src)
          event_name = transition.event.to_s.camalized(:lower)
          exits, entries = transition.exits_and_entries(@sm.get_state(transition.origin_id), @sm.get_state(transition.destination_id))
          add_method(src, "void", event_name, nil) do
            exits.each do |exit|
              src << "statemachine.getContext().#{exit.exit_action.to_s.camalized(:lower)}();" << endl if exit.exit_action
            end
            src << "statemachine.getContext().#{transition.action.to_s.camalized(:lower)}();" << endl if transition.action
            src << "statemachine.setState(statemachine.#{transition.destination_id.to_s.upcase});" << endl
            entries.each do |entry|
              src << "statemachine.getContext().#{entry.entry_action.to_s.camalized(:lower)}();" << endl if entry.entry_action
            end
          end
        end

        def add_one_liner(src, return_type, name, params, body)
          add_method(src, return_type, name, params) do
            src << "#{body};" << endl
          end
        end

        def add_method(src, return_type, name, params)
          src << "public #{return_type} #{name}(#{params})".sub(' ' * 2, ' ') << endl
          begin_scope(src)
          yield
          end_scope(src)
          src << endl
        end

        def begin_scope(src)
          src << "{" << endl
          src.indent!
        end

        def end_scope(src)
          src.undent! << "}" << endl
        end

        def build_context_src
          src = begin_src
          src << "public interface #{@context_classname}" << endl
          begin_scope(src)
          src << "// Actions" << endl
          @action_names.each do |event|
            src << "void #{event}();" << endl
          end
          end_scope(src)
          return src.to_s
        end

        def begin_src
          src = SrcBuilder.new
          src << HEADER1 << endl
          src << HEADER2 << timestamp << endl
          src << "package #{@package};" << endl
          src << endl
          return src
        end

        def create_file(filename, content)
          establish_directory(File.dirname(filename))
          say "Writing to file: #{filename}"
          File.open(filename, 'w') do |file|
            file.write(content)
          end
        end

        def src_file(name)
          path = @output_dir
          if @package
            @package.split(".").each { |segment| path = File.join(path, segment) }
          end
          return File.join(path, "#{name}.java")
        end

      end
    end
  end
end
