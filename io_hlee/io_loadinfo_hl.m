function info = io_loadinfo_hl(infotxtdirectory)
        info_table = readtable(infotxtdirectory);
        for i = 1:height(info_table)
            info.(info_table.Field{i}) = info_table.Value{i}; 
        end
    end