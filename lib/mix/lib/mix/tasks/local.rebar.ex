defmodule Mix.Tasks.Local.Rebar do
  use Mix.Task

  @s3_url             "https://s3.amazonaws.com/s3.hex.pm"
  @rebar2_list_url     @s3_url <> "/installs/rebar-1.x.csv"
  @rebar2_escript_url  @s3_url <> "/installs/[VERSION]/rebar"
  @rebar3_list_url     @s3_url <> "/installs/rebar3-1.x.csv"
  @rebar3_escript_url  @s3_url <> "/installs/[VERSION]/rebar3"

  @shortdoc  "Installs rebar locally"

  @moduledoc """
  Fetches a copy of `rebar` or `rebar3` from the given path or url.

  It defaults to safely download a rebar copy from
  [Amazon S3](https://aws.amazon.com/s3/). However, a URL can be given
  as argument, usually from an existing local copy of rebar. If not
  specified both `rebar` and `rebar3` will be fetched.

  The local copy is stored in your `MIX_HOME` (defaults to `~/.mix`).
  This version of rebar will be used as required by `mix deps.compile`.

  ## Command line options

    * `--sha512` - checks the archive matches the given sha512 checksum

    * `rebar PATH` - specify a path or url for `rebar`

    * `rebar3 PATH` - specify a path or url for `rebar3`

    * `--force` - forces installation without a shell prompt; primarily
      intended for automation in build systems like `make`
  """
  @switches [force: :boolean, sha512: :string]
  @spec run(OptionParser.argv) :: true
  def run(argv) do
    {opts, argv, _} = OptionParser.parse(argv, switches: @switches)

    case argv do
      ["rebar", path | _] ->
       install_from_path(:rebar, path, opts)
      ["rebar3", path | _] ->
       install_from_path(:rebar3, path, opts)
      [] ->
        install_from_s3(:rebar, @rebar2_list_url, @rebar2_escript_url, opts)
        install_from_s3(:rebar3, @rebar3_list_url, @rebar3_escript_url, opts)
    end
  end

  defp install_from_path(manager, path, opts) do
    local = Mix.Rebar.local_rebar_path

    if opts[:force] || Mix.Utils.can_write?(path) do
      case Mix.Utils.read_path(path, opts) do
        {:ok, binary} ->
          File.mkdir_p!(Path.dirname(local))
          File.write!(local, binary)
          File.chmod!(local, 0o755)
          Mix.shell.info [:green, "* creating ", :reset, Path.relative_to_cwd(local)]
        :badpath ->
          Mix.raise "Expected #{inspect path} to be a url or a local file path"
        {:local, message} ->
          Mix.raise message
        {kind, message} when kind in [:remote, :checksum] ->
          Mix.raise """
          #{message}

          Could not fetch #{manager} at:

              #{path}

          Please download the file above manually to your current directory and run:

              mix local.rebar #{manager} ./#{Path.basename(local)}
          """
      end
    end

    true
  end

  defp install_from_s3(manager, list_url, escript_url, opts) do
    {version, sha512} = Mix.Local.find_matching_elixir_version_from_signed_csv!(manager, list_url)
    url = String.replace(escript_url, "[VERSION]", version)
    install_from_path(manager, url, Keyword.put(opts, :sha512, sha512))
  end
end
