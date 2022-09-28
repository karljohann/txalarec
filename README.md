## Usage
1. Add `TxalaRecGui.sc` and `TxalaRecScore.sc` to class library
2. Create a folder to store session information (the path to the folder will be set in `storage_path`)
3. Duplicate `rec_info.scd` to the folder created in step 2. and make sure the channels are correct (note that the system will not run if a `rec_info.scd` file does not exist in the `storage_path` folder)
4. Evaluate the `txalaRecorder.sc` file
- Two windows should open, a settings dialog and the *TxalaRecScore GUI* (if only the settings dialog opens then the `stoarge_path` probably hasn't been set)
- A file named `rec_info.csv` is then created, which contains relevant information about the channels and controls
5. Press Record to record audio and CSV data
- Two files are created: a `csv` file containing data, and a `aiff` file containing the audio recording from all designated channels
6. Duplicate and fill out the `TxalaRecInfo.rtf` and place it in the `storage_path` folder

## Known bugs:
- Control settings are only written at start – if they are changed during recording that is not represented in `rec_info.csv`
- [#6](https://github.com/karljohann/txalarec/issues/6): Pitch detection is not very reliable
- [#5](https://github.com/karljohann/txalarec/issues/5): Amount of planks does not scale – level and pitch are calculated for all included plank channels but the OSC function only sends the first three
- [#4](https://github.com/karljohann/txalarec/issues/4): When there are gaps in the input channels, there will be empty channels (and possibly channels cut off)
