1. Add TxalaRecGui.sc to class library (it requires the TxalaScore class to run)
2. Create a folder and put it's path in the ~storage_path variable at the top of txalaRecorder.sc
(this is the only thing that needs changing there)
3. Duplicate rec_info.scd to the ~storage_path folder and make sure the channels are correct
4. Evaluate TxalaRecorder.sc file
5. Press Record to record audio and data
6. rec_info.csv is created, as are data csv and aiff recordings
7. Remember to fill out TxalaRecInfo.rtf and place it in the ~storage_path folder