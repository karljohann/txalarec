## Usage
1. Add `TxalaRecGui.sc` and `TxalaRecScore.sc` to class library
2. Create a folder to store session information (the path to the folder will be set in `storage_path`)
3. Duplicate `rec_info.scd` to the `storage_path` folder and make sure the channels are correct (note that the system will not run if there is not a `rec_info.scd` file in the `storage_path` folder)
4. Evaluate the `txalaRecorder.sc` file
- Two windows should open, a settings dialog and the TxalaScore GUI – if only the settings dialog opens then the `stoarge_path` probably hasn't been set
5. Press Record to record audio and data
- A file named `rec_info.csv` is created that contains relevant information about the, as are data csv and aiff recordings
6. Duplicate and fill out the `TxalaRecInfo.rtf` and place it in the `storage_path` folder

## Known bugs:
- Pitch detection is not very reliable
- Amount of planks does not scale – level and pitch are calculated for three planks
