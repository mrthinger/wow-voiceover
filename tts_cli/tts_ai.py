import os
from TTS.utils.manage import ModelManager
from TTS.utils.synthesizer import Synthesizer
from tqdm import tqdm

models_path = os.getenv("TTS_MODELS_JSON_PATH")
assets_path = os.getenv("ASSETS_PATH")

print(f"tts models path is located at {models_path}")
print(f"tts assets path is located at {assets_path}")

model_manager = ModelManager(models_path, output_prefix=assets_path)
model_path, _, model_item = model_manager.download_model(
    "tts_models/multilingual/multi-dataset/xtts_v2"
)

print(f"model is {model_item}")

RECREATION_REQUIRED = False

import threading

lock = threading.Lock()

syn = Synthesizer(
    tts_checkpoint=model_path,
    tts_config_path=os.path.join(model_path, "config.json"),
    use_cuda=True,
)


class Singleton(type):
    _instances = {}

    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            with lock:
                if cls not in cls._instances:
                    cls._instances[cls] = super(Singleton, cls).__call__(
                        *args, **kwargs
                    )
        return cls._instances[cls]


class Converter(metaclass=Singleton):
    def __init__(self):
        self.tqdm_bar_format = "{l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}, {rate_fmt}] {postfix}"
        self.tqdm = None
        self.failed_inputs = []

    def convert(self, text, input_sound_path, output_sound_path, language):
        print(f"text: {text}")
        print(f"input: {input_sound_path}")
        print(f"output: {output_sound_path}")

        # try:
        # if (RECREATION_REQUIRED is True):
        syn = Synthesizer(
            tts_checkpoint=model_path,
            tts_config_path=os.path.join(model_path, "config.json"),
            use_cuda=True,
        )
        outputs = syn.tts(
            text=text,
            speaker_name=None,
            language_name=language,
            speaker_wav=input_sound_path,
            reference_wav=None,
            style_wav=None,
            style_text=None,
            reference_speaker_name=None,
            split_sentences=True,
        )

        return syn.save_wav(outputs, output_sound_path)

        # except:
        #    self.failed_inputs.append(input_sound_path)

        # return None

    def process_dataframe(self, df, num_processes, executor, row_proccesing_fn):
        total_rows = len(df)
        chunk_size = int(df.shape[0] / num_processes)

        print(f"total rows: {total_rows}")
        print(f"chunk size: {chunk_size}")

        if self.tqdm is None:
            self.tqdm = tqdm(
                total=total_rows,
                unit="rows",
                ncols=100,
                desc="Generating Audio",
                ascii=False,
                bar_format=self.tqdm_bar_format,
                dynamic_ncols=True,
            )

        chunks = [
            df.iloc[df.index[i : i + chunk_size]]
            for i in range(0, df.shape[0], chunk_size)
        ]

        for chunk in chunks:
            for custom_message in zip(
                executor.map(row_proccesing_fn, chunk.itertuples())
            ):
                self.tqdm.set_postfix_str(custom_message)
                self.tqdm.update(1)

        print(self.failed_inputs)
