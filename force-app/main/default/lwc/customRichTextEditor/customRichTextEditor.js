/* eslint-disable @lwc/lwc/no-inner-html */
import { LightningElement, api } from "lwc";
import { loadStyle, loadScript } from "lightning/platformResourceLoader";
import quilljs from "@salesforce/resourceUrl/quilljs";

export default class CustomRichTextEditor extends LightningElement {
  @api placeholder = "Write something...";
  @api readOnly = false;

  _value = "";
  lastSentValue = "";
  quillInitialized = false;
  quill;

  @api
  get value() {
    return this._value;
  }
  set value(val) {
    this._value = val || "";
    if (this.quill) {
      const currentHtml = this.quill.root.innerHTML;
      if (currentHtml !== this._value && this._value !== this.lastSentValue) {
        this.quill.root.innerHTML = this._value;
        this.lastSentValue = this._value;
      }
    }
  }

  renderedCallback() {
    if (this.quillInitialized) {
      return;
    }
    this.quillInitialized = true;

    Promise.all([
      loadScript(this, quilljs + "/quill.js"),
      loadStyle(this, quilljs + "/quill.snow.css")
    ])
      .then(() => {
        this.initializeQuill();
      })
      .catch((error) => {
        // eslint-disable-next-line no-console
        console.error("Error loading Quill: ", error);
      });
  }

  initializeQuill() {
    if (!window.Quill) {
      return;
    }
    const container = this.template.querySelector(".editor");
    const toolbarOptions = [
      [{ header: [1, 2, 3, false] }],
      ["bold", "italic", "underline", "strike"],
      ["blockquote", "code-block"],
      [{ list: "ordered" }, { list: "bullet" }],
      ["link", "image"],
      ["clean"]
    ];

    this.quill = new window.Quill(container, {
      modules: {
        toolbar: {
          container: toolbarOptions,
          handlers: {
            image: this.handleImageHandler.bind(this)
          }
        }
      },
      placeholder: this.placeholder,
      theme: "snow",
      readOnly: this.readOnly
    });

    if (this._value) {
      this.quill.root.innerHTML = this._value;
      this.lastSentValue = this._value;
    }

    this.quill.on("text-change", () => {
      const html = this.quill.root.innerHTML;
      // If editor contains empty paragraph (Quill default when blank), treat it as empty string
      const normalizedHtml = html === "<p><br></p>" ? "" : html;
      this._value = normalizedHtml;
      this.lastSentValue = normalizedHtml;
      this.dispatchEvent(
        new CustomEvent("change", {
          detail: { value: normalizedHtml }
        })
      );
    });
  }

  handleImageHandler() {
    const input = document.createElement("input");
    input.setAttribute("type", "file");
    input.setAttribute("accept", "image/*");
    input.click();

    input.onchange = async () => {
      const file = input.files[0];
      if (!file) return;

      try {
        const processed = await this.compressImage(file);
        const range = this.quill.getSelection();
        const base64Src = `data:image/jpeg;base64,${processed.base64Data}`;

        // Insert the compressed base64 image into the editor
        // Note: selection index fallback to end of text if range is null
        const index = range ? range.index : this.quill.getLength();
        this.quill.insertEmbed(index, "image", base64Src);
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error("Error processing image: ", err);
      }
    };
  }

  compressImage(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const img = new Image();
        img.onload = () => {
          try {
            const canvas = document.createElement("canvas");
            let width = img.width;
            let height = img.height;
            const MAX_WIDTH = 1200;
            const MAX_HEIGHT = 900;

            if (width > MAX_WIDTH || height > MAX_HEIGHT) {
              const widthRatio = MAX_WIDTH / width;
              const heightRatio = MAX_HEIGHT / height;
              const bestRatio = Math.min(widthRatio, heightRatio);
              width = Math.round(width * bestRatio);
              height = Math.round(height * bestRatio);
            }

            canvas.width = width;
            canvas.height = height;
            const ctx = canvas.getContext("2d");
            ctx.drawImage(img, 0, 0, width, height);

            const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
            const base64Data = dataUrl.split(",")[1];
            resolve({ base64Data });
          } catch (err) {
            reject(err);
          }
        };
        img.onerror = () => reject(new Error("Failed to load image"));
        img.src = e.target.result;
      };
      reader.onerror = () => reject(new Error("Failed to read file"));
      reader.readAsDataURL(file);
    });
  }
}
