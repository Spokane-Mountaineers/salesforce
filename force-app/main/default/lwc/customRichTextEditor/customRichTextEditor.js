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
  globalClickListener;

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

  connectedCallback() {
    // Setup global listener to dismiss drop downs on click outside (Shadow DOM helper)
    this.globalClickListener = (event) => {
      if (!this.quill) return;
      const path = event.composedPath();
      const expandedPickers = this.template.querySelectorAll(
        ".ql-picker.ql-expanded"
      );
      expandedPickers.forEach((picker) => {
        if (!path.includes(picker)) {
          picker.classList.remove("ql-expanded");
        }
      });
    };
    document.addEventListener("click", this.globalClickListener);
  }

  disconnectedCallback() {
    if (this.globalClickListener) {
      document.removeEventListener("click", this.globalClickListener);
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

    // Force selection update on click/keyup to sync toolbar state in Shadow DOM
    this.quill.root.addEventListener("keyup", () => {
      if (this.quill) {
        this.quill.selection.update("user");
      }
    });
    this.quill.root.addEventListener("click", () => {
      if (this.quill) {
        this.quill.selection.update("user");
      }
    });

    // Intercept Enter key inside heading blocks to automatically format newline as normal
    this.quill.keyboard.addBinding({
      key: "Enter",
      handler: (range, context) => {
        if (context.format.header) {
          this.quill.insertText(range.index, "\n", "user");
          this.quill.formatLine(range.index + 1, 1, "header", false, "user");
          this.quill.setSelection(range.index + 1, "user");
          return false;
        }
        return true;
      }
    });

    // Drag-and-drop support for inline pictures
    const editorRoot = this.quill.root;
    editorRoot.addEventListener("dragover", (event) => {
      event.preventDefault();
    });

    editorRoot.addEventListener("drop", async (event) => {
      event.preventDefault();
      const files = event.dataTransfer.files;
      if (files && files.length > 0) {
        let index = this.quill.getLength();
        const currentSel = this.quill.getSelection();
        if (currentSel) {
          index = currentSel.index;
        }

        for (const file of files) {
          if (file.type.startsWith("image/")) {
            try {
              // eslint-disable-next-line no-await-in-loop
              const processed = await this.compressImage(file);
              const base64Src = `data:image/jpeg;base64,${processed.base64Data}`;
              this.quill.insertEmbed(index, "image", base64Src);
              index += 1;
            } catch (err) {
              // eslint-disable-next-line no-console
              console.error("Error dropping image: ", err);
            }
          }
        }
      }
    });

    // Paste from clipboard support for inline pictures
    editorRoot.addEventListener("paste", async (event) => {
      const items = (event.clipboardData || window.clipboardData).items;
      for (const item of items) {
        if (item.type.indexOf("image") === 0) {
          event.preventDefault();
          const file = item.getAsFile();
          try {
            // eslint-disable-next-line no-await-in-loop
            const processed = await this.compressImage(file);
            const base64Src = `data:image/jpeg;base64,${processed.base64Data}`;
            const range = this.quill.getSelection();
            const index = range ? range.index : this.quill.getLength();
            this.quill.insertEmbed(index, "image", base64Src);
          } catch (err) {
            // eslint-disable-next-line no-console
            console.error("Error pasting image: ", err);
          }
        }
      }
    });

    // Add tooltips to formatting options
    this.addTooltips();

    this.quill.on("text-change", () => {
      const html = this.quill.root.innerHTML;
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

  addTooltips() {
    const tooltips = {
      "ql-bold": "Bold",
      "ql-italic": "Italic",
      "ql-underline": "Underline",
      "ql-strike": "Strikethrough",
      "ql-blockquote": "Blockquote",
      "ql-code-block": "Code Block",
      "ql-link": "Insert Link",
      "ql-image": "Insert Image",
      "ql-clean": "Clear Formatting"
    };

    for (const selector in tooltips) {
      if (Object.prototype.hasOwnProperty.call(tooltips, selector)) {
        const elements = this.template.querySelectorAll("." + selector);
        elements.forEach((el) => {
          el.setAttribute("title", tooltips[selector]);
        });
      }
    }

    // Specially handle lists because they have values
    const orderedList = this.template.querySelector(
      '.ql-list[value="ordered"]'
    );
    if (orderedList) orderedList.setAttribute("title", "Numbered List");

    const bulletList = this.template.querySelector('.ql-list[value="bullet"]');
    if (bulletList) bulletList.setAttribute("title", "Bulleted List");

    // Specially handle headers picker
    const picker = this.template.querySelector(".ql-header.ql-picker");
    if (picker) {
      picker.setAttribute("title", "Heading Format");
    }
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
