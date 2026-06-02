classdef Turb < ads.nast.gust.BaseSettings

properties
    RMS = [];
    LengthScale = 2500 ./ SI.ft;
    RLOAD_id = nan;         % to define loading case
    GUST_id = nan;          % to define gust analysis
    RANDOM_id = nan;        % to define random turbulence
    TABLED1_id = nan;       % to define freq dependent load    
    TableRand_id = nan;     % to define turbulence spectrum

    Type = 'VonKarman';

    % user specified psdf
    userFreqs = NaN;        % frequencies for TABRND1 entry
    userPSDs = NaN;         % PSD values corresponding to frequencies in userFreqs
    userAxisTypes = {"LINEAR", "LINEAR"}
end
methods
    function obj = Turb(TurbRMS, TurbType, userFreqs, userPSDs, opts)
        arguments
            TurbRMS double
            TurbType char {mustBeMember(TurbType,{'VonKarman', 'user'})} = 'VonKarman'
            userFreqs (1,:) double = NaN
            userPSDs (1,:) double = NaN
            opts.userXtype string  {mustBeMember(opts.userXtype,["LINEAR","LOG"])} = "LINEAR"
            opts.userYtype string  {mustBeMember(opts.userYtype,["LINEAR","LOG"])} = "LINEAR"
        end

        obj.RMS = TurbRMS;
        obj.Type = TurbType;
        obj.userFreqs = userFreqs;
        obj.userPSDs = userPSDs;
        obj.userAxisTypes = {opts.userXtype, opts.userYtype};
    end
    function ids = UpdateID(obj,ids)
        obj.RLOAD_id = ids.SID;
        obj.GUST_id = ids.SID+1;
        obj.RANDOM_id = ids.SID+2;
        obj.TABLED1_id = ids.TID;
        obj.TableRand_id = ids.TID+1;
        ids.SID = ids.SID + 3;
        ids.TID = ids.TID + 2;
    end
    function write_subcase(obj,fid,idx)
        fprintf(fid,'SUBCASE  %.0f\n',idx);
        fprintf(fid,'GUST = %.0f\n',obj.GUST_id);
        fprintf(fid,'DLOAD = %.0f\n',obj.RLOAD_id);
        fprintf(fid,'RANDOM = %.0f\n',obj.RANDOM_id);
    end
    function obj = set_params(obj,V,opts)
        arguments
            obj
            V
            opts.alt = nan %altitude in feet
        end
        switch obj.Type
            case 'VonKarman'
                if ~isnan(opts.alt)
                    alt = min(max(opts.alt,0),60000);
                    u_ref = interp1([0,24e3,60e3],[27.43,24.08,24.08],alt);
                    obj.RMS = u_ref;
                    obj.LengthScale = 2500 ./ SI.ft;
                end
            otherwise
                if ~strcmp(obj.Type,'user')
                    error('Incorrect Gust Type')
                end
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
        mni.printing.bdf.writeComment(fid,sprintf('Gust Subcase %.0f Properties',i))
        mni.printing.bdf.writeColumnDelimiter(fid,'8');
        % Gust Signal
        obj.set_params(V,'alt',opts.alt);
        mni.printing.cards.GUST(obj.GUST_id,obj.RLOAD_id,1/V,0,V).writeToFile(fid);
        mni.printing.cards.RLOAD1(obj.RLOAD_id,DAREA_id,'TC',obj.TABLED1_id).writeToFile(fid);
        mni.printing.cards.TABLED1(obj.TABLED1_id,opts.FreqRange,ones(size(opts.FreqRange))).writeToFile(fid);
        mni.printing.cards.RANDPS(obj.RANDOM_id,idx,idx,1,0,"TID",obj.TableRand_id).writeToFile(fid);
        if strcmp(obj.Type,'VonKarman')
            mni.printing.cards.TABRNDG(obj.TableRand_id,1,obj.LengthScale/V,obj.RMS).writeToFile(fid);
        elseif strcmp(obj.Type,'user')
            mni.printing.cards.TABRND1(obj.TableRand_id, obj.userFreqs, obj.userPSDs, XAXIS=obj.userAxisTypes{1}, YAXIS=obj.userAxisTypes{2}).writeToFile(fid);
        else
            error(strcat("'", obj.Type, "' is not a valid turbulence type"))
        end
    end
end
end
