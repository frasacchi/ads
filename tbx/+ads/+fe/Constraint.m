classdef Constraint < ads.fe.Element
    properties
        Point ads.fe.Point;
        ComponentNumbers double;
        ID double = nan;
    end
    methods
        function obj = Constraint(Point,ComponentNumbers)
            arguments
                Point ads.fe.Point
                ComponentNumbers double;
            end
            obj.Point = Point;
            obj.ComponentNumbers = ComponentNumbers;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.SID;
                ids.SID = ids.SID + 1;
            end
        end
        function plt_obj = drawElement(obj)
            arguments
                obj
            end
            if isempty(obj)
                plt_obj = [];
                return
            end
            ps = [obj.Point];
            Xs = [ps.GlobalPos];
            plt_obj = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'c^');
            plt_obj.MarkerFaceColor = 'c';
            plt_obj.Tag = "Constraint";
        end
        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"SPC1 : Defines single-point constraints.");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(obj)
                    tmpCard = mni.printing.cards.SPC1(obj(i).ID,...
                        obj(i).ComponentNumbers,obj(i).Point.ID);
                    tmpCard.writeToFile(fid);
                end
            end
        end
    end
end

