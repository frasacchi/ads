% % classdef Material < ads.fe.Element
% %     %MATERIAL Summary of this class goes here
% %     %   Detailed explanation goes here
% % 
% %     properties
% %         E = 0
% %         G = 0;
% %         rho = 0;
% %         nu = 0;
% %         yield = nan;
% %         ID = nan;
% %     end
% % 
% %     methods
% %         function obj = Material(E,nu,rho,opts)
% %             arguments
% %                 E double
% %                 nu double
% %                 rho double
% %                 opts.yield double = nan
% %                 opts.G double = nan
% %             end
% %             obj.E = E;
% %             obj.nu = nu;
% %             obj.rho = rho;
% %             if isnan(opts.G)
% %                 obj.G  = E / (2 * (1 + nu));
% %             else
% %                 obj.G = opts.G;
% %             end
% %             obj.yield = opts.yield;
% %         end
% %         function ids = UpdateID(obj,ids)
% %             for i = 1:length(obj)
% %                 obj(i).ID = ids.MID;
% %                 ids.MID = ids.MID + 1;
% %             end
% %         end
% %         function Export(obj,fid)
% %             if ~isempty(obj)
% %                 mni.printing.bdf.writeComment(fid,"MAT1 : Defines the material properties for linear isotropic materials.");
% %                 mni.printing.bdf.writeColumnDelimiter(fid,"long")
% %                 for i = 1:length(obj)
% %                     tmpCard = mni.printing.cards.MAT1(obj(i).ID,"RHO",obj(i).rho,"NU",obj(i).nu,"G",obj(i).G,"E",obj(i).E);
% %                     tmpCard.LongFormat = true;
% %                     tmpCard.writeToFile(fid);
% %                 end
% %             end
% %         end
% %     end
% %     methods(Static)
% %         function obj = Aluminium()
% %             obj = ads.fe.Material(71.7e9,0.33,2810);
% %             obj.Name = "Aluminium7075";
% %         end
% %         function obj = Stainless304()
% %             obj = ads.fe.Material(193e9,0.29,7930);
% %             obj.Name = "Stainless304";
% %         end
% %         function obj = Stiff()
% %             obj = ads.fe.Material(inf,0,0);
% %             obj.Name = "Stiff";
% %         end
% %         function obj = FromBaffMat(mat)
% %             arguments
% %                 mat baff.Material
% %             end
% %             obj = ads.fe.Material(mat.E,mat.nu,mat.rho,yield=mat.yield,G=mat.G);
% %             obj.Name = mat.Name;
% %         end
% %     end
% % end
% % 

% classdef Material < ads.fe.Element
%     properties
%         E = 0
%         G = 0;
%         rho = 0;
%         nu = 0;
%         yield = nan;
%         ID = nan;
%         MAT string = "MAT1";
%         E1 = nan; E2 = nan;
%         NU12 = nan;
%         G12 = nan; G1Z = nan; G2Z = nan;
%         Xt = nan; Xc = nan; Yt = nan; Yc = nan; S = nan;
%     end
%     methods
%         function obj = Material(E, nu, rho, opts)
%             arguments
%                 E double
%                 nu double
%                 rho double
%                 opts.yield double = nan
%                 opts.G double = nan
%             end
%             obj.E = E;
%             obj.nu = nu;
%             obj.rho = rho;
%             if isnan(opts.G)
%                 obj.G = E / (2 * (1 + nu));
%             else
%                 obj.G = opts.G;
%             end
%             obj.yield = opts.yield;
%         end
%         function ids = UpdateID(obj, ids)
%             for i = 1:length(obj)
%                 obj(i).ID = ids.MID;
%                 ids.MID = ids.MID + 1;
%             end
%         end
%         function Export(obj, fid)
%             if isempty(obj); return; end
%             iso = arrayfun(@(o) o.MAT == "MAT1", obj);
%             if any(iso)
%                 mni.printing.bdf.writeComment(fid, "MAT1 : Linear isotropic.");
%                 mni.printing.bdf.writeColumnDelimiter(fid, "long")
%                 for i = find(iso(:)')
%                     card = mni.printing.cards.MAT1(obj(i).ID, "RHO", obj(i).rho, "NU", obj(i).nu, "G", obj(i).G, "E", obj(i).E);
%                     card.LongFormat = true;
%                     card.writeToFile(fid);
%                 end
%             end
%             if any(~iso)
%                 mni.printing.bdf.writeComment(fid, "MAT8 : 2D orthotropic.");
%                 mni.printing.bdf.writeColumnDelimiter(fid, "long")
%                 for i = find(~iso(:)')
%                     args = {obj(i).ID, "E1", obj(i).E1, "E2", obj(i).E2, "NU12", obj(i).NU12, "G12", obj(i).G12, "RHO", obj(i).rho};
%                     if ~isnan(obj(i).G1Z); args = [args, {"G1Z", obj(i).G1Z}]; end
%                     if ~isnan(obj(i).G2Z); args = [args, {"G2Z", obj(i).G2Z}]; end
%                     if ~isnan(obj(i).Xt);  args = [args, {"Xt",  obj(i).Xt}];  end
%                     if ~isnan(obj(i).Xc);  args = [args, {"Xc",  obj(i).Xc}];  end
%                     if ~isnan(obj(i).Yt);  args = [args, {"Yt",  obj(i).Yt}];  end
%                     if ~isnan(obj(i).Yc);  args = [args, {"Yc",  obj(i).Yc}];  end
%                     if ~isnan(obj(i).S);   args = [args, {"S",   obj(i).S}];   end
%                     card = mni.printing.cards.MAT8(args{:});
%                     card.LongFormat = true;
%                     card.writeToFile(fid);
%                 end
%             end
%         end
%     end
%     methods(Static)
%         function obj = Aluminium()
%             obj = ads.fe.Material(71.7e9, 0.33, 2810);
%             obj.Name = "Aluminium7075";
%         end
%         function obj = Stainless304()
%             obj = ads.fe.Material(193e9, 0.29, 7930);
%             obj.Name = "Stainless304";
%         end
%         function obj = Stiff()
%             obj = ads.fe.Material(inf, 0, 0);
%             obj.Name = "Stiff";
%         end
%         function obj = FromBaffMat(mat)
%             arguments
%                 mat baff.Material
%             end
%             obj = ads.fe.Material(mat.E, mat.nu, mat.rho, yield=mat.yield, G=mat.G);
%             obj.Name = mat.Name;
%             obj.MAT  = mat.MAT;
%             obj.E1   = mat.E1;   obj.E2  = mat.E2;   obj.NU12 = mat.NU12;
%             obj.G12  = mat.G12;  obj.G1Z = mat.G1Z;  obj.G2Z  = mat.G2Z;
%             obj.Xt   = mat.Xt;   obj.Xc  = mat.Xc;
%             obj.Yt   = mat.Yt;   obj.Yc  = mat.Yc;   obj.S    = mat.S;
%         end
%     end
% end

classdef Material < ads.fe.Element
    properties
        E = 0
        G = 0;
        rho = 0;
        nu = 0;
        yield = nan;
        ID = nan;
        MAT string = "MAT1";
        E1 = nan; E2 = nan;
        NU12 = nan;
        G12 = nan; G1Z = nan; G2Z = nan;
        % stress allowables
        Xt = nan; Xc = nan; Yt = nan; Yc = nan; S = nan;
        % strain allowables (added 09/06/2026) — NaN by default; derived
        % from stress/modulus on demand via getAllowables() if not set.
        eXt = nan; eXc = nan;
        eYt = nan; eYc = nan; eS = nan;
    end
    methods
        function obj = Material(E, nu, rho, opts)
            arguments
                E double
                nu double
                rho double
                opts.yield double = nan
                opts.G double = nan
            end
            obj.E = E;
            obj.nu = nu;
            obj.rho = rho;
            if isnan(opts.G)
                obj.G = E / (2 * (1 + nu));
            else
                obj.G = opts.G;
            end
            obj.yield = opts.yield;
        end
        function ids = UpdateID(obj, ids)
            for i = 1:length(obj)
                obj(i).ID = ids.MID;
                ids.MID = ids.MID + 1;
            end
        end
        function Export(obj, fid)
            if isempty(obj); return; end
            iso = arrayfun(@(o) o.MAT == "MAT1", obj);
            if any(iso)
                mni.printing.bdf.writeComment(fid, "MAT1 : Linear isotropic.");
                mni.printing.bdf.writeColumnDelimiter(fid, "long")
                for i = find(iso(:)')
                    card = mni.printing.cards.MAT1(obj(i).ID, "RHO", obj(i).rho, "NU", obj(i).nu, "G", obj(i).G, "E", obj(i).E);
                    card.LongFormat = true;
                    card.writeToFile(fid);
                end
            end
            if any(~iso)
                mni.printing.bdf.writeComment(fid, "MAT8 : 2D orthotropic.");
                mni.printing.bdf.writeColumnDelimiter(fid, "long")
                for i = find(~iso(:)')
                    args = {obj(i).ID, "E1", obj(i).E1, "E2", obj(i).E2, "NU12", obj(i).NU12, "G12", obj(i).G12, "RHO", obj(i).rho};
                    if ~isnan(obj(i).G1Z); args = [args, {"G1Z", obj(i).G1Z}]; end
                    if ~isnan(obj(i).G2Z); args = [args, {"G2Z", obj(i).G2Z}]; end
                    if ~isnan(obj(i).Xt);  args = [args, {"Xt",  obj(i).Xt}];  end
                    if ~isnan(obj(i).Xc);  args = [args, {"Xc",  obj(i).Xc}];  end
                    if ~isnan(obj(i).Yt);  args = [args, {"Yt",  obj(i).Yt}];  end
                    if ~isnan(obj(i).Yc);  args = [args, {"Yc",  obj(i).Yc}];  end
                    if ~isnan(obj(i).S);   args = [args, {"S",   obj(i).S}];   end
                    card = mni.printing.cards.MAT8(args{:});
                    card.LongFormat = true;
                    card.writeToFile(fid);
                end
            end
        end

        function al = getAllowables(obj, overrides)
            %GETALLOWABLES Returns the failure allowables struct for this
            %material. Strain allowables fall back to (stress / modulus)
            %where not explicitly set. Optional `overrides` struct field
            %values take precedence over both.
            %
            % Output struct fields:
            %   Xt, Xc, Yt, Yc, S       (stress, Pa)  — positive magnitudes
            %   eXt, eXc, eYt, eYc, eS  (strain)      — positive magnitudes
            arguments
                obj (1,1)
                overrides struct = struct()
            end
            al.Xt = obj.Xt;  al.Xc = obj.Xc;
            al.Yt = obj.Yt;  al.Yc = obj.Yc;  al.S  = obj.S;
            al.eXt = obj.eXt; al.eXc = obj.eXc;
            al.eYt = obj.eYt; al.eYc = obj.eYc; al.eS = obj.eS;
            if isnan(al.eXt) && ~isnan(al.Xt) && ~isnan(obj.E1) && obj.E1>0
                al.eXt = al.Xt / obj.E1;
            end
            if isnan(al.eXc) && ~isnan(al.Xc) && ~isnan(obj.E1) && obj.E1>0
                al.eXc = al.Xc / obj.E1;
            end
            if isnan(al.eYt) && ~isnan(al.Yt) && ~isnan(obj.E2) && obj.E2>0
                al.eYt = al.Yt / obj.E2;
            end
            if isnan(al.eYc) && ~isnan(al.Yc) && ~isnan(obj.E2) && obj.E2>0
                al.eYc = al.Yc / obj.E2;
            end
            if isnan(al.eS) && ~isnan(al.S) && ~isnan(obj.G12) && obj.G12>0
                al.eS = al.S / obj.G12;
            end
            fns = fieldnames(overrides);
            for k = 1:numel(fns)
                if isfield(al, fns{k})
                    al.(fns{k}) = overrides.(fns{k});
                end
            end
        end
    end
    methods(Static)
        function obj = Aluminium()
            obj = ads.fe.Material(71.7e9, 0.33, 2810);
            obj.Name = "Aluminium7075";
        end
        function obj = Stainless304()
            obj = ads.fe.Material(193e9, 0.29, 7930);
            obj.Name = "Stainless304";
        end
        function obj = Stiff()
            obj = ads.fe.Material(inf, 0, 0);
            obj.Name = "Stiff";
        end
        function obj = FromBaffMat(mat)
            arguments
                mat baff.Material
            end
            obj = ads.fe.Material(mat.E, mat.nu, mat.rho, yield=mat.yield, G=mat.G);
            obj.Name = mat.Name;
            obj.MAT  = mat.MAT;
            obj.E1   = mat.E1;   obj.E2  = mat.E2;   obj.NU12 = mat.NU12;
            obj.G12  = mat.G12;  obj.G1Z = mat.G1Z;  obj.G2Z  = mat.G2Z;
            obj.Xt   = mat.Xt;   obj.Xc  = mat.Xc;
            obj.Yt   = mat.Yt;   obj.Yc  = mat.Yc;   obj.S    = mat.S;
            % propagate strain allowables (NaN-safe)
            if isprop(mat, 'eXt'), obj.eXt = mat.eXt; end
            if isprop(mat, 'eXc'), obj.eXc = mat.eXc; end
            if isprop(mat, 'eYt'), obj.eYt = mat.eYt; end
            if isprop(mat, 'eYc'), obj.eYc = mat.eYc; end
            if isprop(mat, 'eS'),  obj.eS  = mat.eS;  end
        end
    end
end