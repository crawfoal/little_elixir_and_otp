defmodule Ex6 do
  def parse(packet) do
    << header :: binary-size(20), _content :: binary >> = packet
    <<
      version :: size(4),
      header_length :: size(4),
      tos :: size(8),
      total_length :: size(16),
      fragment_id :: size(16),
      _evil_bit :: size(1),
      dont_fragment :: size(1),
      more_fragments :: size(1),
      fragment_offset :: size(13),
      ttl :: size(8),
      protocol :: size(8),
      header_checksum :: size(16),
      source :: size(32),
      destination :: size(32),
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
      source: source, #|> IP.Address.from_binary!() |> IP.Address.to_string(),
      destination: destination #|> IP.Address.from_binary!() |> IP.Address.to_string()
    }
  end

  defp parse_bool(0), do: false
  defp parse_bool(1), do: true
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
    #assert parsed_packet.fragment_id == << 173, 11 >>
    assert parsed_packet.dont_fragment == false
    assert parsed_packet.more_fragments == false
    assert parsed_packet.fragment_offset == 0
    assert parsed_packet.ttl == 64
    assert parsed_packet.protocol == 17
    #assert parsed_packet.header_checksum == << 114, 114 >>
    #assert parsed_packet.source == "172.20.2.253"
    #assert parsed_packet.destination == "172.20.0.6"
  end
end

