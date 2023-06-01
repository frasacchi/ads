classdef OneMC < ads.nast.gust.BaseSettings

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
    function obj = OneMC(GustAmplitude,GustLength,GustFreq,GustType)
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
            obj.TLOAD_id = ids.SID;
            obj.DLOAD_id = ids.SID+4;
            obj.GUST_id = ids.SID+5;
            obj.TABLED1_id = ids.TID;
            ids.SID = ids.SID + 6;
            ids.TID = ids.TID + 1;
    end
    function write_subcase(obj,fid,idx)
        fprintf(fid,'SUBCASE  %.0f\n',idx);
        fprintf(fid,'GUST = %.0f\n',obj.GUST_id);
        fprintf(fid,'DLOAD = %.0f\n',obj.DLOAD_id);
    end
    function obj = set_params(obj,V,opts)
        arguments
            obj
            V
            opts.alt = 15000 %altitude in feet
        end
        switch obj.Type
            case 'Length'
                obj.Freq = V/obj.Length;
            case 'Length_atmos'
                obj.Freq = V/obj.Length;
                alt = min(max(opts.alt,15000),50000);
                w_ref_eas = interp1([0,15e3,60e3],[17.07,13.41,6.36],alt);
                % convert EAS to TAS
                [rho_0,~,~,~,~,~,~] = ads.util.atmos(0);
                [rho,~,~,~,~,~,~] = ads.util.atmos(convlength(alt,'ft','m'));
                w_ref_tas = w_ref_eas.*sqrt(rho_0./rho);
                % calc amplitude
                obj.Amplitude = w_ref_tas*(0.5*obj.Length/106.17).^(1/6);
            case 'Freq'
                obj.Length = V/obj.Freq;
            otherwise
                error('Incorrect Gust Type')
        end
    end
    function write_bdf(obj,fid,DAREA_id,V,idx,opts)
        arguments
            obj
            fid
            DAREA_id
            V
            idx
            opts.alt = 15000 %altitude in feet
            opts.FreqRange = [0 50];
        end
        % still to Complete - write gust as two TLOAD2 cards.... (see Ali's examples)
        mni.printing.bdf.writeComment(fid,sprintf('Gust Subcase %.0f Properties',i))
        mni.printing.bdf.writeColumnDelimiter(fid,'8');
        % Gust Signal
        obj.set_params(V,'alt',opts.alt);
        mni.printing.cards.TLOAD2(obj.TLOAD_id,DAREA_id,'F',0,'T1',obj.Tdelay,'T2',obj.Tdelay+(1/obj.Freq)).writeToFile(fid);
        mni.printing.cards.TLOAD2(obj.TLOAD_id+1,DAREA_id,'F',obj.Freq,'T1',obj.Tdelay,'T2',obj.Tdelay+(1/obj.Freq)).writeToFile(fid);
        mni.printing.cards.DLOAD(obj.DLOAD_id,1,[0.5,-0.5],[obj.TLOAD_id,obj.TLOAD_id+1]).writeToFile(fid);
        mni.printing.cards.GUST(obj.GUST_id,obj.DLOAD_id,obj.Amplitude/V,0,V).writeToFile(fid);
    end
end
end
