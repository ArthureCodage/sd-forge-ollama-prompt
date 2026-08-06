import json
import urllib.request
import urllib.error

import gradio as gr

from modules import scripts, script_callbacks, shared


DEFAULT_SYSTEM_PROMPT = """You are an expert prompt engineer for Stable Diffusion image generation.
Given a theme, concept, or idea, you craft detailed, high-quality prompts that produce stunning images.

Rules:
- Output ONLY the prompt text, no explanations or conversation
- Include details about: subject, lighting, composition, style, mood, colors, technical quality tags
- Keep prompts concise but descriptive (50-120 words)
- End with quality boosters like: masterpiece, best quality, highly detailed, 8k, sharp focus
- Adapt style to the subject (photorealistic, anime, painterly, etc.)
- Separate elements with commas
- Avoid banned/inappropriate content"""

STYLE_PRESETS = {
    "Photographie réaliste": "professional photography, photorealistic, RAW photo, DSLR quality",
    "Anime/Manga": "anime style, vibrant colors, clean lines, manga illustration",
    "Peinture à l'huile": "oil painting, classical art, brushstrokes, fine art, museum quality",
    "Digital Art": "digital art, trending on ArtStation, concept art, illustration",
    "Fantasy": "fantasy art, ethereal lighting, magical atmosphere, epic composition",
    "Cyberpunk": "cyberpunk aesthetic, neon lights, futuristic, sci-fi atmosphere",
    "Horror": "dark atmosphere, horror style, dramatic lighting, unsettling mood",
    "Minimaliste": "minimalist, clean composition, simple elegance, negative space",
    "Pixel Art": "pixel art, retro gaming style, 16-bit, nostalgic",
    "Surréaliste": "surrealist, dreamlike, Salvador Dali inspired, bizarre composition",
}

NEGATIVE_ENHANCE = """deformed, distorted, disfigured, poorly drawn, bad anatomy, wrong anatomy,
extra limb, missing limb, floating limbs, mutated hands, extra fingers, fused fingers,
too many fingers, long neck, out of frame, cropped, low quality, worst quality,
blurry, jpeg artifacts, watermark, text, signature, username, error"""


class OllamaPromptScript(scripts.Script):
    sorting_priority = 15

    def title(self):
        return "Ollama Prompt Generator"

    def show(self, is_img2img):
        return scripts.AlwaysVisible

    def ui(self, is_img2img):
        with gr.Accordion(open=False, label=self.title()):
            with gr.Row():
                enabled = gr.Checkbox(label="Activer Ollama", value=False)
                ollama_status = gr.Textbox(
                    label="Statut",
                    value="Non connecté",
                    interactive=False,
                    scale=2,
                )
                test_btn = gr.Button("Tester connexion", size="sm")

            with gr.Row():
                model_dropdown = gr.Dropdown(
                    label="Modèle Ollama",
                    choices=[],
                    value=None,
                    allow_custom_value=True,
                )
                refresh_btn = gr.Button("Rafraîchir", size="sm")

            with gr.Row():
                theme_input = gr.Textbox(
                    label="Thème / Idée",
                    placeholder="Ex: un chat astronaute sur Mars",
                    lines=1,
                )

            with gr.Row():
                style_preset = gr.Dropdown(
                    label="Style preset",
                    choices=list(STYLE_PRESETS.values()),
                    value=list(STYLE_PRESETS.values())[0],
                )

            with gr.Row():
                temperature = gr.Slider(
                    label="Température",
                    minimum=0.0,
                    maximum=2.0,
                    step=0.1,
                    value=0.7,
                )
                max_tokens = gr.Slider(
                    label="Tokens max",
                    minimum=50,
                    maximum=500,
                    step=10,
                    value=200,
                )

            with gr.Row():
                generate_btn = gr.Button("Générer le prompt", variant="primary")

            prompt_output = gr.Textbox(
                label="Prompt généré",
                lines=4,
                interactive=False,
            )

            with gr.Row():
                send_txt2img = gr.Button("→ txt2img", size="sm")
                send_img2img = gr.Button("→ img2img", size="sm")
                copy_prompt = gr.Button("Copier", size="sm")

            with gr.Accordion(open=False, label="Prompt système"):
                system_prompt = gr.Textbox(
                    label="System prompt",
                    value=DEFAULT_SYSTEM_PROMPT,
                    lines=8,
                )

        def test_connection():
            url = shared.opts.ollama_url
            try:
                req = urllib.request.Request(
                    f"{url}/api/tags",
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=5) as resp:
                    data = json.loads(resp.read().decode())
                    models = [m["name"] for m in data.get("models", [])]
                    if models:
                        return (
                            gr.update(value=f"✓ Connecté ({len(models)} modèles)"),
                            gr.update(choices=models, value=models[0]),
                        )
                    return (
                        gr.update(value="✓ Connecté (aucun modèle)"),
                        gr.update(choices=[], value=None),
                    )
            except Exception as e:
                return (
                    gr.update(value=f"✗ Erreur: {str(e)[:50]}"),
                    gr.update(choices=[], value=None),
                )

        def refresh_models():
            url = shared.opts.ollama_url
            try:
                req = urllib.request.Request(
                    f"{url}/api/tags",
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read().decode())
                    models = [m["name"] for m in data.get("models", [])]
                    return gr.update(choices=models, value=models[0] if models else None)
            except Exception:
                return gr.update(choices=[], value=None)

        def generate(theme, style, temp, max_tok, system):
            url = shared.opts.ollama_url
            model = shared.opts.ollama_model

            if not theme.strip():
                return "Veuillez entrer un thème ou une idée."

            full_prompt = (
                f"Subject: {theme}\n"
                f"Style requirement: {style}\n\n"
                f"Generate a Stable Diffusion prompt:"
            )

            payload = {
                "model": model,
                "prompt": full_prompt,
                "system": system,
                "stream": False,
                "options": {
                    "temperature": temp,
                    "num_predict": int(max_tok),
                },
            }

            try:
                data = json.dumps(payload).encode("utf-8")
                req = urllib.request.Request(
                    f"{url}/api/generate",
                    data=data,
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=120) as resp:
                    result = json.loads(resp.read().decode())
                    prompt = result.get("response", "").strip()
                    return prompt
            except urllib.error.URLError as e:
                return f"Erreur de connexion: {e}"
            except Exception as e:
                return f"Erreur: {e}"

        test_btn.click(
            fn=test_connection,
            outputs=[ollama_status, model_dropdown],
        )

        refresh_btn.click(
            fn=refresh_models,
            outputs=[model_dropdown],
        )

        generate_btn.click(
            fn=generate,
            inputs=[theme_input, style_preset, temperature, max_tokens, system_prompt],
            outputs=[prompt_output],
        )

        send_txt2img.click(
            fn=lambda p: gr.Textbox.update(value=p) if p else None,
            inputs=[prompt_output],
            outputs=[],
        )

        return (
            enabled,
            theme_input,
            style_preset,
            temperature,
            max_tokens,
            system_prompt,
            prompt_output,
        )

    def process(self, p, *args, **kwargs):
        pass


def on_ui_tabs():
    with gr.Blocks(analytics_enabled=False, title="Ollama Prompt") as ollama_tab:
        with gr.Tab(label="Ollama Prompt Generator"):
            with gr.Row():
                with gr.Column(scale=1):
                    gr.Markdown("### Configuration Ollama")
                    with gr.Row():
                        status_indicator = gr.Textbox(
                            label="Statut",
                            value="Cliquez pour tester",
                            interactive=False,
                        )
                        test_conn_btn = gr.Button("🔄 Tester", size="sm")

                    model_select = gr.Dropdown(
                        label="Modèle",
                        choices=[],
                        allow_custom_value=True,
                    )
                    refresh_models_btn = gr.Button("Rafraîchir la liste")

                    gr.Markdown("### Paramètres")
                    temp_slider = gr.Slider(
                        label="Température", minimum=0.0, maximum=2.0, step=0.1, value=0.7
                    )
                    tokens_slider = gr.Slider(
                        label="Tokens max", minimum=50, maximum=500, step=10, value=200
                    )

                    style_dropdown = gr.Dropdown(
                        label="Style",
                        choices=list(STYLE_PRESETS.values()),
                        value=list(STYLE_PRESETS.values())[0],
                    )

                with gr.Column(scale=2):
                    gr.Markdown("### Génération de prompt")
                    theme_box = gr.Textbox(
                        label="Thème / Concept / Idée",
                        placeholder="Décrivez ce que vous voulez générer...\nEx: 'Un phare au bord d'une falaise pendant un orage'",
                        lines=2,
                    )

                    gen_btn = gr.Button("✨ Générer le prompt", variant="primary", size="lg")

                    output_box = gr.Textbox(
                        label="Prompt généré",
                        lines=6,
                        interactive=True,
                    )

                    with gr.Row():
                        send_to_txt2img = gr.Button("📸 Envoyer vers txt2img", size="sm")
                        send_to_img2img = gr.Button("🖼️ Envoyer vers img2img", size="sm")

                    with gr.Accordion(open=False, label="Options avancées"):
                        sys_prompt_box = gr.Textbox(
                            label="Prompt système",
                            value=DEFAULT_SYSTEM_PROMPT,
                            lines=10,
                        )

                        neg_prompt_box = gr.Textbox(
                            label="Prompt négatif",
                            value=NEGATIVE_ENHANCE,
                            lines=3,
                        )

                        enhance_mode = gr.Checkbox(
                            label="Mode amélioration (utilise le thème comme prompt existant à enrichir)",
                            value=False,
                        )

        def _test_connection():
            url = shared.opts.ollama_url
            try:
                req = urllib.request.Request(
                    f"{url}/api/tags",
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=5) as resp:
                    data = json.loads(resp.read().decode())
                    models = [m["name"] for m in data.get("models", [])]
                    if models:
                        return (
                            gr.update(value=f"✓ Connecté ({len(models)} modèles)"),
                            gr.update(choices=models, value=models[0]),
                        )
                    return (
                        gr.update(value="✓ Connecté (aucun modèle installé)"),
                        gr.update(choices=[], value=None),
                    )
            except Exception as e:
                return (
                    gr.update(value=f"✗ {str(e)[:60]}"),
                    gr.update(choices=[], value=None),
                )

        def _refresh_models():
            url = shared.opts.ollama_url
            try:
                req = urllib.request.Request(
                    f"{url}/api/tags",
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read().decode())
                    models = [m["name"] for m in data.get("models", [])]
                    return gr.update(choices=models, value=models[0] if models else None)
            except Exception:
                return gr.update(choices=[], value=None)

        def _generate(theme, style, temp, max_tok, system, enhance):
            url = shared.opts.ollama_url
            model = shared.opts.ollama_model

            if not theme.strip():
                return "Veuillez entrer un thème, concept ou idée."

            if enhance:
                user_prompt = (
                    f"This is an existing Stable Diffusion prompt: '{theme}'\n"
                    f"Style to apply: {style}\n\n"
                    f"Enhance this prompt to make it more detailed and visually compelling. "
                    f"Add appropriate lighting, composition, mood, and quality tags. "
                    f"Keep the core subject intact. Output ONLY the enhanced prompt."
                )
            else:
                user_prompt = (
                    f"Subject: {theme}\n"
                    f"Style requirement: {style}\n\n"
                    f"Generate a detailed Stable Diffusion prompt. Output ONLY the prompt text."
                )

            payload = {
                "model": model,
                "prompt": user_prompt,
                "system": system,
                "stream": False,
                "options": {
                    "temperature": temp,
                    "num_predict": int(max_tok),
                },
            }

            try:
                data = json.dumps(payload).encode("utf-8")
                req = urllib.request.Request(
                    f"{url}/api/generate",
                    data=data,
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=180) as resp:
                    result = json.loads(resp.read().decode())
                    return result.get("response", "").strip()
            except urllib.error.URLError as e:
                return f"Erreur de connexion à Ollama: {e}"
            except Exception as e:
                return f"Erreur: {e}"

        test_conn_btn.click(
            fn=_test_connection,
            outputs=[status_indicator, model_select],
        )

        refresh_models_btn.click(
            fn=_refresh_models,
            outputs=[model_select],
        )

        gen_btn.click(
            fn=_generate,
            inputs=[theme_box, style_dropdown, temp_slider, tokens_slider, sys_prompt_box, enhance_mode],
            outputs=[output_box],
        )

    return [(ollama_tab, "Ollama Prompt", "ollama_prompt_tab")]


def on_ui_settings():
    ollama_section = ("ollama_prompt", "Ollama Prompt Generator")

    shared.opts.add_option(
        "ollama_url",
        shared.OptionInfo(
            "http://localhost:11434",
            "URL du serveur Ollama",
            gr.Textbox,
            {"interactive": True},
            section=ollama_section,
        ),
    )

    shared.opts.add_option(
        "ollama_model",
        shared.OptionInfo(
            "llama3.2",
            "Modèle Ollama par défaut",
            gr.Textbox,
            {"interactive": True},
            section=ollama_section,
        ),
    )


script_callbacks.on_ui_tabs(on_ui_tabs)
script_callbacks.on_ui_settings(on_ui_settings)
