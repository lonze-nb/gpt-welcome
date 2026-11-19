const form = document.querySelector("form");
const input = document.querySelector("#message");
const preview = document.querySelector(".greeting");
const status = document.querySelector("#status");
const download = document.querySelector("#download");

function greeting() {
  return input.value.trim() || defaultGreeting;
}

function updatePreview() {
  showGreeting(preview, greeting());
  status.textContent = "";
}

input.addEventListener("input", updatePreview);
document.querySelector("#replay").addEventListener("click", () => animateGreeting(preview, greeting()));
updatePreview();

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const message = greeting();
  if (/[\u0000-\u001f\u007f-\u009f]/u.test(message) ||
      new TextEncoder().encode(message).length > 512) {
    status.textContent = "请输入不含控制字符的欢迎语。";
    return;
  }
  download.disabled = true;
  status.textContent = "正在生成下载包…";
  try {
    let template;
    const embedded = document.querySelector("#app-template");
    if (embedded) {
      template = Uint8Array.from(atob(embedded.textContent.trim()), char => char.charCodeAt(0));
    } else {
      const response = await fetch("app-template.zip");
      if (!response.ok) throw new Error("ZIP template could not be loaded");
      template = new Uint8Array(await response.arrayBuffer());
    }
    const zip = appendZipFile(template, "greeting.json", JSON.stringify({ greeting: message }) + "\n");
    const url = URL.createObjectURL(zip);
    const link = document.createElement("a");
    link.href = url;
    link.download = "GPT Welcome.zip";
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
    status.textContent = "已生成下载包。";
  } catch {
    status.textContent = "生成失败，请重新加载此页再试。";
  } finally {
    download.disabled = false;
  }
});
