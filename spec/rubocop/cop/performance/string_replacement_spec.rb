# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Performance::StringReplacement, :config do
  it 'accepts methods other than gsub' do
    expect_no_offenses("'abc'.insert(2, 'a')")
  end

  shared_examples 'accepts' do |method|
    context 'non deterministic parameters' do
      it 'accepts gsub when the length of the pattern is greater than 1' do
        expect_no_offenses("'abc'.#{method}('ab', 'de')")
      end

      it 'accepts the first param being a variable' do
        expect_no_offenses(<<~RUBY)
          regex = /a/
          'abc'.#{method}(regex, '1')
        RUBY
      end

      it 'accepts the second param being a variable' do
        expect_no_offenses(<<~RUBY)
          replacement = 'e'
          'abc'.#{method}('abc', replacement)
        RUBY
      end

      it 'accepts the both params being a variables' do
        expect_no_offenses(<<~RUBY)
          regex = /a/
          replacement = 'e'
          'abc'.#{method}(regex, replacement)
        RUBY
      end

      it 'accepts gsub with only one param' do
        expect_no_offenses("'abc'.#{method}('a')")
      end

      it 'accepts gsub with a block' do
        expect_no_offenses("'abc'.#{method}('a') { |s| s.upcase } ")
      end

      it 'accepts a pattern with string interpolation' do
        expect_no_offenses(<<~RUBY)
          foo = 'a'
          'abc'.#{method}(\"\#{foo}\", '1')
        RUBY
      end

      it 'accepts a replacement with string interpolation' do
        expect_no_offenses(<<~RUBY)
          foo = '1'
          'abc'.#{method}('a', \"\#{foo}\")
        RUBY
      end

      it 'allows empty regex literal pattern' do
        expect_no_offenses("'abc'.#{method}(//, '1')")
      end

      it 'allows empty regex pattern from string' do
        expect_no_offenses("'abc'.#{method}(Regexp.new(''), '1')")
      end

      it 'allows empty regex pattern from regex' do
        expect_no_offenses("'abc'.#{method}(Regexp.new(//), '1')")
      end

      it 'allows regex literals with options' do
        expect_no_offenses("'abc'.#{method}(/a/i, '1')")
      end

      it 'allows regex with options' do
        expect_no_offenses("'abc'.#{method}(Regexp.new(/a/i), '1')")
      end

      it 'allows empty string pattern' do
        expect_no_offenses("'abc'.#{method}('', '1')")
      end
    end

    it 'accepts calls to gsub when the length of the pattern is shorter than ' \
       'the length of the replacement' do
      expect_no_offenses("'abc'.#{method}('a', 'ab')")
    end

    it 'accepts calls to gsub when the length of the pattern is longer than ' \
       'the length of the replacement' do
      expect_no_offenses("'abc'.#{method}('ab', 'd')")
    end
  end

  it_behaves_like('accepts', 'gsub')
  it_behaves_like('accepts', 'gsub!')

  describe 'deterministic regex' do
    describe 'regex literal' do
      it 'registers an offense when using space' do
        expect_offense(<<~RUBY)
          'abc'.gsub(/ /, '')
                ^^^^^^^^^^^^^ Use `delete` instead of `gsub`.
        RUBY
      end

      %w[a b c ' " % ! = < > # & ; : ` ~ 1 2 3 - _ , \r \\\\ \y \u1234
         \x65].each do |str|
        it "registers an offense when replacing #{str} with a literal" do
          expect_offense(<<~RUBY, str: str)
            'abc'.gsub(/#{str}/, 'a')
                  ^^^^^^^{str}^^^^^^^ Use `tr` instead of `gsub`.
          RUBY
        end

        it "registers an offense when deleting #{str}" do
          expect_offense(<<~RUBY, str: str)
            'abc'.gsub(/#{str}/, '')
                  ^^^^^^^{str}^^^^^^ Use `delete` instead of `gsub`.
          RUBY
        end
      end

      it 'allows deterministic regex when the length of the pattern ' \
         'and the length of the replacement do not match' do
        expect_no_offenses(%('abc'.gsub(/a/, 'def')))
      end

      it 'registers an offense when escape characters in regex' do
        expect_offense(<<~RUBY)
          'abc'.gsub(/\\n/, ',')
                ^^^^^^^^^^^^^^^ Use `tr` instead of `gsub`.
        RUBY
      end

      it 'registers an offense when using %r notation' do
        expect_offense(<<~RUBY)
          '/abc'.gsub(%r{a}, 'd')
                 ^^^^^^^^^^^^^^^^ Use `tr` instead of `gsub`.
        RUBY
      end
    end

    describe 'regex constructor' do
      it 'registers an offense when only using word characters' do
        expect_offense(<<~RUBY)
          'abc'.gsub(Regexp.new('b'), '2')
                ^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `tr` instead of `gsub`.
        RUBY
      end

      it 'registers an offense when regex is built from regex' do
        expect_offense(<<~RUBY)
          'abc'.gsub(Regexp.new(/b/), '2')
                ^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `tr` instead of `gsub`.
        RUBY
      end

      it 'registers an offense when using compile' do
        expect_offense(<<~RUBY)
          '123'.gsub(Regexp.compile('1'), 'a')
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `tr` instead of `gsub`.
        RUBY
      end
    end
  end

  describe 'non deterministic regex' do
    it 'allows regex containing a +' do
      expect_no_offenses("'abc'.gsub(/a+/, 'def')")
    end

    it 'allows regex containing a *' do
      expect_no_offenses("'abc'.gsub(/a*/, 'def')")
    end

    it 'allows regex containing a ^' do
      expect_no_offenses("'abc'.gsub(/^/, '')")
    end

    it 'allows regex containing a $' do
      expect_no_offenses("'abc'.gsub(/$/, '')")
    end

    it 'allows regex containing a ?' do
      expect_no_offenses("'abc'.gsub(/a?/, 'def')")
    end

    it 'allows regex containing a .' do
      expect_no_offenses("'abc'.gsub(/./, 'a')")
    end

    it 'allows regex containing a |' do
      expect_no_offenses("'abc'.gsub(/a|b/, 'd')")
    end

    it 'allows regex containing ()' do
      expect_no_offenses("'abc'.gsub(/(ab)/, 'd')")
    end

    it 'allows regex containing escaped ()' do
      expect_no_offenses("'(abc)'.gsub(/(ab)/, 'd')")
    end

    it 'allows regex containing {}' do
      expect_no_offenses("'abc'.gsub(/a{3,}/, 'd')")
    end

    it 'allows regex containing []' do
      expect_no_offenses("'abc'.gsub(/[a-z]/, 'd')")
    end

    it 'allows regex containing a backslash' do
      expect_no_offenses('"abc".gsub(/\\s/, "d")')
    end

    it 'allows regex literal containing interpolations' do
      expect_no_offenses(<<~'RUBY')
        foo = 'a'
        "abc".gsub(/#{foo}/, "d")
      RUBY
    end

    it 'allows regex constructor containing a string with interpolations' do
      expect_no_offenses(<<~'RUBY')
        foo = 'a'
        "abc".gsub(Regexp.new("#{foo}"), "d")
      RUBY
    end

    it 'allows regex constructor containing regex with interpolations' do
      expect_no_offenses(<<~'RUBY')
        foo = 'a'
        "abc".gsub(Regexp.new(/#{foo}/), "d")
      RUBY
    end
  end

  it 'registers an offense when the pattern has non deterministic regex ' \
     'as a string' do
    expect_offense(<<~RUBY)
      'a + c'.gsub('+', '-')
              ^^^^^^^^^^^^^^ Use `tr` instead of `gsub`.
    RUBY
  end

  it 'registers an offense when using gsub to find and replace ' \
     'a single character' do
    expect_offense(<<~RUBY)
      'abc'.gsub('a', '1')
            ^^^^^^^^^^^^^^ Use `tr` instead of `gsub`.
    RUBY
  end

  it 'registers an offense when using gsub! to find and replace a single character' do
    expect_offense(<<~RUBY)
      'abc'.gsub!('a', '1')
            ^^^^^^^^^^^^^^^ Use `tr!` instead of `gsub!`.
    RUBY
  end

  it 'registers an offense for gsub! when deleting one characters' do
    expect_offense(<<~RUBY)
      'abc'.gsub!('a', '')
            ^^^^^^^^^^^^^^ Use `delete!` instead of `gsub!`.
    RUBY
  end

  context 'auto-correct' do
    describe 'corrects to tr' do
      it 'corrects when the length of the pattern and replacement are one' do
        new_source = autocorrect_source("'abc'.gsub('a', 'd')")

        expect(new_source).to eq("'abc'.tr('a', 'd')")
      end

      it 'corrects when the pattern is a regex literal' do
        new_source = autocorrect_source("'abc'.gsub(/a/, '1')")

        expect(new_source).to eq("'abc'.tr('a', '1')")
      end

      it 'corrects when the pattern is a regex literal using %r' do
        new_source = autocorrect_source("'abc'.gsub(%r{a}, '1')")

        expect(new_source).to eq("'abc'.tr('a', '1')")
      end

      it 'corrects when the pattern uses Regexp.new' do
        new_source = autocorrect_source("'abc'.gsub(Regexp.new('a'), '1')")

        expect(new_source).to eq("'abc'.tr('a', '1')")
      end

      it 'corrects when the pattern uses Regexp.compile' do
        new_source = autocorrect_source("'abc'.gsub(Regexp.compile('a'), '1')")

        expect(new_source).to eq("'abc'.tr('a', '1')")
      end

      it 'corrects when the replacement contains a new line character' do
        new_source = autocorrect_source("'abc'.gsub('a', '\n')")

        expect(new_source).to eq("'abc'.tr('a', '\n')")
      end

      it 'corrects when the replacement contains escape backslash' do
        new_source = autocorrect_source("\"\".gsub('/', '\\\\')")

        expect(new_source).to eq("\"\".tr('/', '\\\\')")
      end

      it 'corrects when the pattern contains a new line character' do
        new_source = autocorrect_source("'abc'.gsub('\n', ',')")

        expect(new_source).to eq("'abc'.tr('\n', ',')")
      end

      it 'corrects when the pattern contains double backslash' do
        new_source = autocorrect_source("''.gsub('\\\\', '')")

        expect(new_source).to eq("''.delete('\\\\')")
      end

      it 'corrects when replacing to a single quote' do
        new_source = autocorrect_source('"a`b".gsub("`", "\'")')

        expect(new_source).to eq('"a`b".tr("`", "\'")')
      end

      it 'corrects when replacing to a double quote' do
        new_source = autocorrect_source('"a`b".gsub("`", "\"")')

        expect(new_source).to eq('"a`b".tr("`", "\"")')
      end
    end

    describe 'corrects to delete' do
      it 'corrects when deleting a single character' do
        new_source = autocorrect_source("'abc'.gsub!('a', '')")

        expect(new_source).to eq("'abc'.delete!('a')")
      end

      it 'corrects when the pattern is a regex literal' do
        new_source = autocorrect_source("'abc'.gsub(/a/, '')")

        expect(new_source).to eq("'abc'.delete('a')")
      end

      it 'corrects when deleting an escape character' do
        new_source = autocorrect_source("'abc'.gsub('\n', '')")

        expect(new_source).to eq("'abc'.delete('\n')")
      end

      it 'corrects when the pattern uses Regexp.new' do
        new_source = autocorrect_source("'abc'.gsub(Regexp.new('a'), '')")

        expect(new_source).to eq("'abc'.delete('a')")
      end

      it 'corrects when the pattern uses Regexp.compile' do
        new_source = autocorrect_source("'ab'.gsub(Regexp.compile('a'), '')")

        expect(new_source).to eq("'ab'.delete('a')")
      end

      it 'corrects when there are no brackets' do
        new_source = autocorrect_source("'abc'.gsub! 'a', ''")

        expect(new_source).to eq("'abc'.delete! 'a'")
      end

      it 'corrects when a regexp contains escapes' do
        new_source = autocorrect_source("'abc'.gsub(/\\n/, '')")

        expect(new_source).to eq(%('abc'.delete("\\n")))
      end
    end
  end
end
