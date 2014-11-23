describe "Fortitude widgets and 'yield'", :type => :system do
  it "should call the block passed to the constructor when you call 'yield' from #content" do
    wc = widget_class do
      def content
        text "before"
        yield
        text "after"
      end
    end

    expect(render(wc.new { |widget| widget.text "middle" })).to eq("beforemiddleafter")
  end

  it "should raise a clear error if you try to 'yield' from #content and there is no block passed" do
    wc = widget_class do
      def content
        text "before"
        yield
        text "after"
      end
    end

    instance = wc.new
    e = capture_exception(::Fortitude::Errors::NoBlockToYieldTo) { render(instance) }
    expect(e.message).to match(/#{Regexp.escape(instance.to_s)}/)
    expect(e.widget).to eq(instance)
  end

  it "should allow you to pass the block from #content to another method and run it from there just fine" do
    wc = widget_class do
      def content(&block)
        text "before"
        foo(&block)
        text "after"
      end

      def foo
        text "inner_before"
        yield
        text "inner_after"
      end
    end

    expect(render(wc.new { |widget| widget.text "middle" })).to eq("beforeinner_beforemiddleinner_afterafter")
  end

  it "should allow you to call that same block using #yield_from_widget in #content" do
    wc = widget_class do
      def content
        text "before"
        yield_from_widget
        text "after"
      end
    end

    expect(render(wc.new { |widget| widget.text "middle" })).to eq("beforemiddleafter")
  end

  it "should allow you to call that same block using #yield_from_widget in some other method, too" do
    wc = widget_class do
      def content
        text "before"
        foo
        text "after"
      end

      def foo
        text "inner_before"
        yield_from_widget
        text "inner_after"
      end
    end

    expect(render(wc.new { |widget| widget.text "middle" })).to eq("beforeinner_beforemiddleinner_afterafter")
  end

  it "should allow you to pass a block to #widget, and it should work the same way as passing it to the constructor" do
    wc_sub = widget_class do
      def content
        text "inner_before"
        yield
        text "inner_after"
      end
    end

    wc = widget_class do
      cattr_accessor :other_widget_class

      def content
        text "before"
        widget(self.class.other_widget_class) { text "middle"  }
        text "after"
      end
    end

    wc.other_widget_class = wc_sub
    expect(render(wc.new)).to eq("beforeinner_beforemiddleinner_afterafter")
  end

  it "should allow you to pass a block to #widget, and it should work the same way as passing it to the constructor, even if #widget is given a fully-intantiated widget" do
    wc_sub = widget_class do
      def content
        text "inner_before"
        yield
        text "inner_after"
      end
    end

    wc = widget_class do
      cattr_accessor :other_widget_class

      def content
        text "before"
        sub_widget = self.class.other_widget_class.new
        widget(sub_widget) { text "middle"  }
        text "after"
      end
    end

    wc.other_widget_class = wc_sub
    expect(render(wc.new)).to eq("beforeinner_beforemiddleinner_afterafter")
  end

  it "should use the block passed to #widget in preference to the one in the constructor, if both are passed" do
    wc_sub = widget_class do
      def content
        text "inner_before"
        yield
        text "inner_after"
      end
    end

    wc = widget_class do
      cattr_accessor :other_widget_class

      def content
        text "before"
        sub_widget = self.class.other_widget_class.new { text "foobar" }
        widget(sub_widget) { text "middle"  }
        text "after"
      end
    end

    wc.other_widget_class = wc_sub
    expect(render(wc.new)).to eq("beforeinner_beforemiddleinner_afterafter")
  end

  it "should use the block passed to the constructor in preference to the layout, if both exist" do
    the_rc = rc(:yield_block => lambda { raise "kaboomba" })

    wc = widget_class do
      def content
        text "before"
        yield
        text "after"
      end
    end

    expect(render(wc.new { |widget| widget.text "middle" }, :rendering_context => the_rc)).to eq("beforemiddleafter")
  end

  it "should use the block passed to #content in preference to the one from the constructor or the layout" do
    the_rc = rc(:yield_block => lambda { raise "kaboomba" })

    wc_sub = widget_class do
      def content
        text "inner_before"
        yield
        text "inner_after"
      end
    end

    wc = widget_class do
      cattr_accessor :other_widget_class

      def content
        text "before"
        other = self.class.other_widget_class.new { text "foobar" }
        widget(other) { text "middle" }
        text "after"
      end
    end

    wc.other_widget_class = wc_sub

    expect(render(wc.new { |widget| widget.text "constructor" }, :rendering_context => the_rc)).to eq("beforeinner_beforemiddleinner_afterafter")
  end

  it "should allow creating an elegant modal-dialog widget" do
    modal_dialog_module = Module.new do
      cattr_accessor :modal_dialog_class

      def modal_dialog(title, options = { }, &block)
        widget modal_dialog_class.new(options.merge(:title => title), &block)
      end
    end

    modal_section_class = widget_class do
      needs :section_title

      def content
        div(:class => 'modal_section') do
          h5 "Modal section: #{section_title}"

          yield("#{section_title}345", "456#{section_title}")
        end
      end
    end

    modal_dialog_class = widget_class do
      cattr_accessor :modal_section_class

      needs :title, :button_text => 'Go!'

      def content
        div(:class => 'modal_dialog') do
          h3 "Modal title: #{title}"

          yield("#{title}123", "234#{title}")

          button button_text, :class => 'modal_button'
        end
      end

      def modal_section(title, &block)
        widget(modal_section_class.new(:section_title => title), &block)
      end
    end

    modal_dialog_class.modal_section_class = modal_section_class
    modal_dialog_module.modal_dialog_class = modal_dialog_class

    wc = widget_class do
      needs :name

      def banner(text)
        p(text, :class => 'banner')
      end

      def content
        h1 "Name: #{name}"

        modal_dialog('Details', :button_text => 'Submit Details') { |modal_arg1, modal_arg2|
          banner "Before details modal_section for #{name}: #{modal_arg1}, #{modal_arg2}"

          modal_section("Details for #{name}") { |section_arg1, section_arg2|
            p "These are the details for #{name}: #{section_arg1}, #{section_arg2}"
          }

          p "After details modal_section for #{name}"
        }

        modal_dialog('Security', :button_text => 'Submit Security') { |modal_arg1, modal_arg2|
          banner "Before security modal_section for #{name}: #{modal_arg1}, #{modal_arg2}"

          modal_section("Security for #{name}") { |section_arg1, section_arg2|
            text "These are the security settings for #{name}: #{section_arg1}, #{section_arg2}"
          }

          text "After security modal_section for #{name}"
        }
      end
    end

    wc.send(:include, modal_dialog_module)

    $stderr.puts "modal_dialog_class: #{modal_dialog_class}"
    $stderr.puts "wc: #{wc}"
    expect(render(wc.new(:name => 'Jones'))).to eq('XXX')
  end
end
