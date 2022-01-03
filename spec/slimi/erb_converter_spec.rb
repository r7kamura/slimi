# frozen_string_literal: true

RSpec.describe Slimi::ErbConverter do
  describe '#call' do
    subject do
      described_class.new.call(slim)
    end

    let(:slim) do
      <<~'SLIM'
        doctype 5
        html
          head
            title Hello World!
            /! Meta tags
              with long explanatory
              multiline comment
            meta name="description" content="template language"
            /! Stylesheets
            link href="style.css" media="screen" rel="stylesheet" type="text/css"
            link href="colors.css" media="screen" rel="stylesheet" type="text/css"
            /! Javascripts
            script src="jquery.js"
            script src="jquery.ui.js"
            /[if lt IE 9]
              script src="old-ie1.js"
              script src="old-ie2.js"
            css:
              body {
                background-color: red;
              }
          body
            #container
              p Hello
                World!
              p= "dynamic text with\nnewline"
      SLIM
    end

    it 'converts Slim into ERB' do
      is_expected.to eq(<<~'ERB'.delete_suffix("\n"))
        <!DOCTYPE html>
        <html>
        <head>
        <title>Hello World!</title>
        <!--Meta tags
        with long explanatory
        multiline comment-->
        <meta content="template language" name="description" />
        <!--Stylesheets-->
        <link href="style.css" media="screen" rel="stylesheet" type="text/css" />
        <link href="colors.css" media="screen" rel="stylesheet" type="text/css" />
        <!--Javascripts-->
        <script src="jquery.js">
        </script><script src="jquery.ui.js">
        </script><!--[if lt IE 9]>
        <script src="old-ie1.js">
        </script><script src="old-ie2.js">
        </script><![endif]--><style type="text/css">
        body {
        background-color: red;
        }</style>
        </head><body>
        <div id="container">
        <p>Hello
        World!</p>
        <p><%= ::Temple::Utils.escape_html(("dynamic text with\nnewline")) %>
        </p></div></body></html>
      ERB
    end
  end
end
