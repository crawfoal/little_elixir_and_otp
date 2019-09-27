defmodule Ex6 do
  def parse(packet) do
    << header :: binary-size(20), _content :: binary >> = packet
    <<
      version :: integer-size(4),
      header_length :: integer-size(4),
      tos :: integer-size(8), # I think maybe this should stay a binary?
      total_length :: integer-size(16),
      fragment_id :: binary-size(2),
      _evil_bit :: integer-size(1),
      dont_fragment :: integer-size(1),
      more_fragments :: integer-size(1),
      fragment_offset :: integer-size(13),
      ttl :: integer-size(8),
      protocol :: integer-size(8),
      header_checksum :: binary-size(2),
      source :: binary-size(4),
      destination :: binary-size(4),
      _options :: binary
    >> = header
    %{
      version: version,
      header_length: header_length,
      tos: tos,
      total_length: total_length,
      fragment_id: fragment_id,
      dont_fragment: parse_bool(dont_fragment),
      more_fragments: parse_bool(more_fragments),
      fragment_offset: fragment_offset,
      ttl: ttl,
      protocol: protocol,
      header_checksum: header_checksum,
      source: parse_ipv4_address(source),
      destination: parse_ipv4_address(destination)
    }
  end

  defp parse_bool(0), do: false
  defp parse_bool(1), do: true

  # For some reason I couldn't get IP.Address to load ¯\_(ツ)_/¯
  defp parse_ipv4_address(<< a::8, b::8, c::8, d::8 >>),
    do: "#{a}.#{b}.#{c}.#{d}"
end

ExUnit.start()

defmodule Ex6Test do
  use ExUnit.Case, async: true

  test "parse/1" do
    parsed_packet =
      case File.read(Path.join(__DIR__, "dns_packet.bin")) do
        {:ok, packet} -> Ex6.parse(packet)
        {:error, code} -> flunk("Error reading in binary file: #{code}")
      end

    assert parsed_packet.version == 4
    assert parsed_packet.header_length == 5
    assert parsed_packet.tos == 0
    assert parsed_packet.total_length == 68
    assert parsed_packet.fragment_id == << 173, 11 >>
    assert parsed_packet.dont_fragment == false
    assert parsed_packet.more_fragments == false
    assert parsed_packet.fragment_offset == 0
    assert parsed_packet.ttl == 64
    assert parsed_packet.protocol == 17
    assert parsed_packet.header_checksum == << 114, 114 >>
    assert parsed_packet.source == "172.20.2.253"
    assert parsed_packet.destination == "172.20.0.6"
  end
end

