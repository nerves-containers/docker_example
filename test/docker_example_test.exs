defmodule DockerExampleTest do
  use ExUnit.Case
  doctest DockerExample

  test "greets the world" do
    assert DockerExample.hello() == :world
  end
end
