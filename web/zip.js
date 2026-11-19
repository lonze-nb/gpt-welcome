// Add one uncompressed file to the app ZIP, preserving the signed bundle
// and all original ZIP records byte for byte. The build emits classic ZIP.
function appendZipFile(template, filename, content) {
  const original = new DataView(template.buffer, template.byteOffset, template.byteLength);
  let end = template.length - 22;
  const earliestEnd = Math.max(0, end - 65535);
  for (; end >= earliestEnd; end--) {
    if (original.getUint32(end, true) === 0x06054b50 &&
        end + 22 + original.getUint16(end + 20, true) === template.length) break;
  }
  if (end < earliestEnd) throw new Error("Missing ZIP directory");
  const count = original.getUint16(end + 10, true);
  const directorySize = original.getUint32(end + 12, true);
  const directoryOffset = original.getUint32(end + 16, true);
  if (original.getUint32(end + 4, true) !== 0 ||
      original.getUint16(end + 8, true) !== count ||
      count >= 65534 || directoryOffset + directorySize !== end) {
    throw new Error("Unsupported ZIP template");
  }

  const encoder = new TextEncoder();
  const name = encoder.encode(filename);
  const data = encoder.encode(content);
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  crc ^= 0xffffffff;

  function record(size, signature, fields16, fields32) {
    const bytes = new Uint8Array(size);
    const view = new DataView(bytes.buffer);
    view.setUint32(0, signature, true);
    for (const [offset, value] of fields16) view.setUint16(offset, value, true);
    for (const [offset, value] of fields32) view.setUint32(offset, value, true);
    return bytes;
  }

  const local = record(30, 0x04034b50,
    [[4, 20], [12, 33], [26, name.length]],
    [[14, crc], [18, data.length], [22, data.length]]);
  const central = record(46, 0x02014b50,
    [[4, 0x0314], [6, 20], [14, 33], [28, name.length]],
    [[16, crc], [20, data.length], [24, data.length], [38, 0x81a40000], [42, directoryOffset]]);
  const footer = record(22, 0x06054b50,
    [[8, count + 1], [10, count + 1]],
    [[12, directorySize + central.length + name.length],
     [16, directoryOffset + local.length + name.length + data.length]]);

  return new Blob([
    template.subarray(0, directoryOffset), local, name, data,
    template.subarray(directoryOffset, end), central, name, footer,
  ], { type: "application/zip" });
}
