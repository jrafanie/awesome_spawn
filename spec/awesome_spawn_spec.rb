require 'spec_helper'
require 'pathname' # For Pathname specific specs

describe AwesomeSpawn do
  subject { described_class }

  shared_examples_for "run" do
    context "options" do
      it "params won't be modified" do
        params      = {:params => {:user => "bob"}}
        orig_params = params.dup
        allow(subject).to receive(:launch).with("true --user bob", {}).and_return(["", "", 0])
        subject.send(run_method, "true", params)
        expect(orig_params).to eq(params)
      end

      it ":params won't be modified" do
        params      = {:user => "bob"}
        orig_params = params.dup
        allow(subject).to receive(:launch).with("true --user bob", {}).and_return(["", "", 0])
        subject.send(run_method, "true", :params => params)
        expect(orig_params).to eq(params)
      end

      it ":in is not supported" do
        expect do
          subject.send(run_method, "true", :in => "/dev/null")
        end.to raise_error(ArgumentError, "options cannot contain :in")
      end

      it ":out is not supported" do
        expect do
          subject.send(run_method, "true", :out => "/dev/null")
        end.to raise_error(ArgumentError, "options cannot contain :out")
      end

      it ":err is not supported" do
        expect do
          subject.send(run_method, "true", :err => "/dev/null")
        end.to raise_error(ArgumentError, "options cannot contain :err")
      end
    end

    context "with real execution" do
      before do
        # Re-enable actual spawning just for these specs.
        enable_spawning
      end

      it "command ok exit ok" do
        expect(subject.send(run_method, "true")).to be_kind_of AwesomeSpawn::CommandResult
      end

      it "command ok exit bad" do
        if run_method == "run!"
          error = nil

          # raise_error with do/end block notation is broken in rspec-expectations 2.14.x
          # and has been fixed in master but not yet released.
          # See: https://github.com/rspec/rspec-expectations/commit/b0df827f4c12870aa4df2f20a817a8b01721a6af
          expect { subject.send(run_method, "false") }.to raise_error {|e| error = e }
          expect(error).to be_kind_of AwesomeSpawn::CommandResultError
          expect(error.result).to be_kind_of AwesomeSpawn::CommandResult
        else
          expect { subject.send(run_method, "false") }.to_not raise_error
        end
      end

      it "command bad" do
        expect do
          subject.send(run_method, "XXXXX --user=bob")
        end.to raise_error(AwesomeSpawn::NoSuchFileError, "No such file or directory - XXXXX")
      end

      context "with option" do
        it ":chdir" do
          result = subject.send(run_method, "pwd", :chdir => "..")
          expect(result.exit_status).to  eq(0)
          expect(result.output.chomp).to eq(File.expand_path("..", Dir.pwd))
        end

        it ":in_data" do
          result = subject.send(run_method, "cat", :in_data => "line1\nline2")
          expect(result.exit_status).to eq(0)
          expect(result.output).to      eq("line1\nline2")
        end
      end

      context "#exit_status" do
        it "command ok exit ok" do
          expect(subject.send(run_method, "echo", :params => %w(x)).command_line).to eq("echo x")
        end

        it "command ok exit bad" do
          if run_method == "run"
            expect(subject.send(run_method, "echo x && false").command_line).to eq("echo x && false")
          end
        end
      end

      context "#exit_status" do
        it "command ok exit ok" do
          expect(subject.send(run_method, "true").exit_status).to eq(0)
        end

        it "command ok exit bad" do
          expect(subject.send(run_method, "false").exit_status).to eq(1) if run_method == "run"
        end
      end

      context "#output" do
        it "command ok exit ok" do
          expect(subject.send(run_method, "echo \"Hello World\"").output).to eq("Hello World\n")
        end

        it "command ok exit bad" do
          expect(subject.send(run_method, "echo 'bad' && false").output).to eq("bad\n") if run_method == "run"
        end

        it "has output even though output redirected to stderr" do
          expect(subject.send(run_method, "echo \"Hello World\" >&2").output).to eq("")
        end
      end

      context "#error" do
        it "has error even though no error" do
          expect(subject.send(run_method, "echo", :params => ["Hello World"]).error).to eq("")
        end

        it "command ok exit ok" do
          expect(subject.send(run_method, "echo \"Hello World\" >&2").error).to eq("Hello World\n")
        end

        it "command ok exit bad" do
          expect(subject.send(run_method, "echo 'bad' >&2 && false").error).to eq("bad\n") if run_method == "run"
        end
      end
    end
  end

  context ".build_command_line" do
    it "should handle single parameter" do
      expect(subject.build_command_line("cmd")).to eq("cmd")
    end

    it "should handle multi parameter" do
      expect(subject.build_command_line("cmd", :status => true)).to eq("cmd --status true")
    end
  end

  context ".run" do
    include_examples "run" do
      let(:run_method) {"run"}
    end
  end

  context ".run!" do
    include_examples "run" do
      let(:run_method) {"run!"}
    end
  end
end
