require "http/server"

module Meteor
  VERSION = "0.1.0"

  STYLE = %{
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
      body {
        background-color: #EFF7F6;
        margin: 2em;
        max-width: 480px;
        font-size: 18px;
        font-family: sans-serif;
      }

      input[type="radio"] {
        display: none;
      }

      .options {
        display: flex;
        flex-direction: row;
        justify-content: space-between;
      }

      label, input[type="submit"] {
        display: inline-block;
        border: 1px solid black;
        padding: 1em 2em;
        cursor: pointer;
        text-align: center;
        font-size: 18px;
      }

      input[type="submit"] {
        background-color: #B2F7EF;
      }

      input[type="submit"]:active {
        color: black;
        background-color: white;
      }

      input[type="radio"]:checked+label {
        background-color: #7BDFF2;
      }
      </style>
    }
end

class Object
  def flap
    yield self
  end

  def puts(io : IO = STDOUT)
    io.puts(self)
  end
end

class Array(T)
  def as_server_handlers : HTTP::Server
    HTTP::Server.new(self)
  end
end

class Questionairre
  include HTTP::Handler

  struct Question
    property label : String
    property topic : String
    property answers : Array(String)

    def initialize(@label : String, @topic : String, @answers : Array(String)); end
  end

  def call(c : HTTP::Server::Context)
    case c.request.path
    when "", "/", "/index", "index" then index(c)
    when "submit", "/submit"        then submit(c)
    else                                 call_next(c)
    end
  end

  def index(c : HTTP::Server::Context)
    c.response.content_type = "text/html"

    questions = [
      Question.new("What did you wear today as a top?", "top", ["light", "medium", "heavy"]),
      Question.new("What did you wear today as a bottom?", "bottom", ["light", "medium", "heavy"]),
      Question.new("Was it comfortable?", "comfort", ["too cool", "just right", "too warm"]),
    ]

    c.response << Meteor::STYLE

    c.response << %{<form method="post" action="/submit">}

    questions.each do |q|
      c.response << %{<div>#{q.label}<div class="options">}
      q.answers.each_with_index do |answer, index|
        c.response << %{
          <input type="radio" id="#{q.topic}-#{answer}" name="#{q.topic}" value="#{answer}" #{index == 1 ? "checked" : ""}/>
          <label for="#{q.topic}-#{answer}">#{answer}</label>
        }
      end
      c.response << %{</div></div><br/><br/>}
    end
    c.response << %{<input type="submit" name="Submit"/></form>}
  end

  def submit(c : HTTP::Server::Context)
    c.response.content_type = "text/html"
    c.response << Meteor::STYLE
    c.response << "<p>Thanks for your help!</p>"
    c.response << "<p>"

    top = ""
    bottom = ""
    comfort = ""

    c.request.body.try do |body|
      HTTP::Params.parse(body.gets_to_end) do |name, value|
        case name
        when "top"     then top = value
        when "bottom"  then bottom = value
        when "comfort" then comfort = value
        end
      end
    end

    c.response << "You wore a #{top} top, "
    c.response << "a #{bottom} bottom, "
    c.response << "and you were #{comfort}."

    c.response << "</p>"
  end
end

[
  HTTP::ErrorHandler.new,
  HTTP::LogHandler.new,
  HTTP::CompressHandler.new,
  Questionairre.new,
  HTTP::StaticFileHandler.new("."),
]
  .as_server_handlers
  .tap(&.bind_tcp(8080))
  .flap { |x| {x, "0.0.0.0", 8888} }
  .tap { |_, y, z|
    "listening on http://%s:%i"
      .flap { |x| x % {y, z} }
      .tap(&.puts)
  }
  .tap { |x, y, z| x.listen(y, z) }
