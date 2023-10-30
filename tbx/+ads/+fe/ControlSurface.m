classdef ControlSurface < ads.fe.Element
    %MASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        AeroSurfaces (:,1) ads.fe.AeroSurface = ads.fe.AeroSurface.empty;
        SID (1,1) double = nan;
        CID (1,1) double = nan;
        ControllerID (1,1) double = nan;
        DeflectionLimit (2,1) double = [-pi/2,pi/2];

        LinkedSurface ads.fe.ControlSurface = ads.fe.ControlSurface.empty;
        LinkedCoefficent = 1;
    end
    
    methods
        function val = RefChord(obj)
            val = (1-obj.AeroSurfaces(1).HingeEta).*obj.AeroSurfaces(1).Chords;
            val = mean(val);
        end
        function val = RefArea(obj)
            chords = (1-obj.AeroSurfaces(1).HingeEta).*obj.AeroSurfaces(1).Chords;
            points = obj.AeroSurfaces(1).Points(1,:);
            span = abs(points(2)-points(1));
            val = 0.5*span*sum(chords);
        end
        function obj = ControlSurface(Name,opts)
            arguments
                Name string
                opts.AeroSurface = ads.fe.AeroSurface.empty;

            end
            obj.Name = Name;
            obj.AeroSurfaces = opts.AeroSurface;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                % for AELIST cards
                obj(i).SID = ids.SID;
                ids.SID = ids.SID + 1;
                % for local Coordsys cards
                obj(i).CID = ids.CID;
                ids.CID = ids.CID + 1;
                % for AESURF cards
                obj(i).ControllerID = ids.ControllerID;
                ids.ControllerID = ids.ControllerID + 1;
            end
        end

        function Export(obj,fid)
            if isempty(obj)
                return
            end
            %create local coord sys
            CS = ads.fe.CoordSys.empty;
            for i = 1:length(obj)
                CS(i) = obj(i).AeroSurfaces(1).getHingeCoordSys();
                CS(i).ID = obj(i).CID;
            end
            CS.Export(fid);
            %create AELIST cards
            mni.printing.bdf.writeComment(fid,"AELIST : Defines lists of aero panel IDs for each control surface");
            mni.printing.bdf.writeColumnDelimiter(fid,"short")
            for i = 1:length(obj)
                idx = [];
                for j = 1:length(obj(i).AeroSurfaces)
                    tmp_IDs = obj(i).AeroSurfaces(j).get_panelIDs();
                    tmp_idx = obj(i).AeroSurfaces(j).HingeIdx();
                    idx = [idx,tmp_IDs(tmp_idx)];
                end
                mni.printing.cards.AELIST(obj(i).SID,idx).writeToFile(fid);
            end
            %create AESURF cards
            mni.printing.bdf.writeComment(fid,"AESURF : Defines control surfaces");
            mni.printing.bdf.writeColumnDelimiter(fid,"short")
            for i = 1:length(obj)
                mni.printing.cards.AESURF(obj(i).ControllerID,obj(i).Name,obj(i).CID,...
                obj(i).SID,'CREFC',obj(i).RefChord,'CREFS',obj(i).RefArea,...
                'PLLIM',obj(i).DeflectionLimit(1),'PULIM',obj(i).DeflectionLimit(2)).writeToFile(fid);
            end
            % Control surface links
            clear cards
            idx = 1;
            for i = 1:length(obj)
                if ~isempty(obj(i).LinkedSurface)
                cards(idx) = mni.printing.cards.AELINK(obj(i).Name,...
                    {{obj(i).LinkedSurface.Name,obj(i).LinkedCoefficent}});
                    
                idx = idx+1;
                end
            end
            if idx>1
                mni.printing.bdf.writeComment(fid,"AELINK : Defines link between control surfaces");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(cards)
                    cards(i).writeToFile(fid);
                end
            end
        end
    end
end

