classdef GustSettings < handle

properties
    Amplitude = [];
    Length = [];
    Freq = [];

    TLOAD_id = nan;
    DLOAD_id = nan;
    GUST_id = nan;
    TABLED1_id = nan;

    Type = 'Freq';
    Tdelay = 0;
end
methods
    function obj = GustSettings(GustAmplitude,GustLength,GustFreq,GustType)
        arguments
            GustAmplitude double
            GustLength double
            GustFreq double
            GustType char {mustBeMember(GustType,{'Freq','Length','Length_atmos'})} = 'Freq'
        end
        obj.Amplitude = GustAmplitude;
        obj.Length = GustLength;
        obj.Freq = GustFreq;
        obj.Type = GustType;
    end
    function ids = UpdateID(obj,ids)
        for i = 1:length(obj)
            obj(i).TLOAD_id = ids.SID;
            obj(i).DLOAD_id = ids.SID+4;
            obj(i).GUST_id = ids.SID+5;
            obj(i).TABLED1_id = ids.TID;
            ids.SID = ids.SID + 6;
            ids.TID = ids.TID + 1;
        end
    end
    function write_gust_subcase(obj,fid)
        for i = 1:length(obj)
            fprintf(fid,'SUBCASE  %.0f\n',i);
            fprintf(fid,'GUST = %.0f\n',obj(i).GUST_id);
            fprintf(fid,'DLOAD = %.0f\n',obj(i).DLOAD_id);
        end
    end
    function obj = set_params(obj,V,opts)
        arguments
            obj
            V
            opts.alt = 15000 %altitude in feet
        end
        for i = 1:length(obj)
            switch obj(i).Type
                case 'Length'
                    obj(i).Freq = V/obj(i).Length;
                case 'Length_atmos'
                    obj(i).Freq = V/obj(i).Length;
                    alt = min(max(opts.alt,15000),50000);
                    w_ref = interp1([0,15e3,60e3],[17.07,13.41,6.36],alt);
                    obj(i).Amplitude = w_ref*(0.5*obj(i).Length/106.17).^(1/6);
                case 'Freq'
                    obj(i).Length = V/obj(i).Freq;
                otherwise
                    error('Incorrect Gust Type')
            end
        end
    end
    % function write_gust_bdf(obj,fid,DAREA_id,V)
    %     for i = 1:length(obj)
    %         % still to Complete - write gust as two TLOAD2 cards.... (see Ali's examples)
    %         mni.printing.bdf.writeComment(fid,sprintf('Gust Subcase %.0f Properties',i))
    %         mni.printing.bdf.writeColumnDelimiter(fid,'8');
    %         % Gust Signal
    %         obj(i).set_params(V);
    %         mni.printing.cards.TLOAD2(obj(i).TLOAD_id,DAREA_id,'F',0,'T1',1,'T2',1+(1/obj(i).Freq)).writeToFile(fid);
    %         mni.printing.cards.TLOAD2(obj(i).TLOAD_id+1,DAREA_id,'F',obj(i).Freq,'T1',1,'T2',1+(1/obj(i).Freq)).writeToFile(fid);
    %         mni.printing.cards.TLOAD2(obj(i).TLOAD_id+2,DAREA_id,'F',0,'T1',obj(i).Tdelay,'T2',obj(i).Tdelay+(1/obj(i).Freq)).writeToFile(fid);
    %         mni.printing.cards.TLOAD2(obj(i).TLOAD_id+3,DAREA_id,'F',obj(i).Freq,'T1',obj(i).Tdelay,'T2',obj(i).Tdelay+(1/obj(i).Freq)).writeToFile(fid);
    %         mni.printing.cards.DLOAD(obj(i).DLOAD_id,1,[-1,1,1,-1],[obj(i).TLOAD_id,obj(i).TLOAD_id+1,obj(i).TLOAD_id+2,obj(i).TLOAD_id+3]).writeToFile(fid);
    %         mni.printing.cards.GUST(obj(i).GUST_id,obj(i).DLOAD_id,obj(i).Amplitude/V,0,V).writeToFile(fid);
    %     end
    % end

    function write_gust_bdf(obj,fid,DAREA_id,V,opts)
        arguments
            obj
            fid
            DAREA_id
            V
            opts.alt = 15000 %altitude in feet
        end
        for i = 1:length(obj)
            % still to Complete - write gust as two TLOAD2 cards.... (see Ali's examples)
            mni.printing.bdf.writeComment(fid,sprintf('Gust Subcase %.0f Properties',i))
            mni.printing.bdf.writeColumnDelimiter(fid,'8');
            % Gust Signal
            obj(i).set_params(V,'alt',opts.alt);
            mni.printing.cards.TLOAD2(obj(i).TLOAD_id,DAREA_id,'F',0,'T1',obj(i).Tdelay,'T2',obj(i).Tdelay+(1/obj(i).Freq)).writeToFile(fid);
            mni.printing.cards.TLOAD2(obj(i).TLOAD_id+1,DAREA_id,'F',obj(i).Freq,'T1',obj(i).Tdelay,'T2',obj(i).Tdelay+(1/obj(i).Freq)).writeToFile(fid);
            mni.printing.cards.DLOAD(obj(i).DLOAD_id,1,[0.5,-0.5],[obj(i).TLOAD_id,obj(i).TLOAD_id+1]).writeToFile(fid);
            mni.printing.cards.GUST(obj(i).GUST_id,obj(i).DLOAD_id,obj(i).Amplitude/V,0,V).writeToFile(fid);
        end
    end
    % function write_gust_bdf(obj,fid,DAREA_id,V)
    %     for i = 1:length(obj)
    %         mni.printing.bdf.writeComment(fid,sprintf('Gust Subcase %.0f Properties',i))
    %         mni.printing.bdf.writeColumnDelimiter(fid,'8');
    %         mni.printing.cards.TLOAD1(obj(i).TLOAD_id,DAREA_id,'TID',obj(i).TABLED1_id).writeToFile(fid);
    %         mni.printing.cards.DLOAD(obj(i).DLOAD_id,1,1,obj(i).TLOAD_id).writeToFile(fid);
    %         % Gust Signal
    %         obj(i).set_params(V);
    %         mni.printing.cards.GUST(obj(i).GUST_id,obj(i).DLOAD_id,obj(i).Amplitude/V,0,V).writeToFile(fid);
    %         t = linspace(0,1/obj(i).Freq,101);
    %         gust = gen_1MC(obj(i).Freq,1,0,t);
    %         t = t + obj(i).Tdelay;
    %         mni.printing.cards.TABLED1(obj(i).TABLED1_id,t,gust).writeToFile(fid);
    %     end
    % end
end
end
