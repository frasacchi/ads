classdef RigidBodyElement < ads.fe.Element
    %BEAM Summary of this class goes here
    %   Detailed explanation goes here

    properties
        %Point1 ads.fe.Point
        %Point2 ads.fe.Point
        EID double = nan;
        REFGRID ads.fe.Point=ads.fe.Point.empty(0,1);
        REFC
        WTi double;
        Ci
        Gi ads.fe.Point=ads.fe.Point.empty(0,1);
        ExportLongFormat logical = true;
    end

    methods
        function obj = RigidBodyElement(REFGRID,REFC,WTi,Ci,Gi)
            arguments
               REFGRID ads.fe.Point
               REFC 
               WTi 
               Ci 
               Gi ads.fe.Point
            end
            obj.REFGRID=REFGRID;
            obj.REFC=REFC;
            obj.WTi = WTi;
            obj.Ci = Ci;
            obj.Gi = Gi;

        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).EID = ids.EID;
                ids.EID = ids.EID + 1;
            end
        end        
        
        function Export(obj,fid)
            if ~isempty(obj)
                % print CBEAM elements
                mni.printing.bdf.writeComment(fid,"RBE3: Defines an MPC element.");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(obj)
                        tmpCard = mni.printing.cards.RBE3(obj(i).EID,obj(i).REFGRID,obj(i).REFC,obj(i).WTi,obj(i).Ci,obj(i).Gi);
                    tmpCard.writeToFile(fid);
                end
            end
        end
    end
end

