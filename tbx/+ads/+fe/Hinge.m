classdef Hinge < ads.fe.Element
    properties
        Points (:,1) ads.fe.Point;
        CoordSys ads.fe.CoordSys;
        ID double = nan;
        PID double = nan;
        K double = 1e-4;
        C double = 0;
        isLocked = false;
    end
    methods
        function obj = Hinge(Points,CoordSys,K,C,opts)
            arguments
                Points (2,1) ads.fe.Point
                CoordSys ads.fe.CoordSys
                K double = 1e-4;
                C double = 0;
                opts.isLocked = false
            end
            obj.Points = Points;
            obj.CoordSys = CoordSys;
            obj.K = K;
            obj.C = C;
            obj.isLocked = opts.isLocked;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.EID;
                ids.EID = ids.EID + 2;
                obj(i).PID = ids.PID;
                ids.PID = ids.PID + 1;
            end
        end
        function plt_obj = draw(obj)
            arguments
                obj
            end
            if isempty(obj)
                plt_obj = [];
                return
            end
            for i = 1:length(obj)
                cs = [obj(i).CoordSys];
                Xs = [cs.getPointGlobal([0.1;0;0]),cs.getOriginGlobal,cs.getPointGlobal([-0.1;0;0])];
                plt_obj(i) = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'ro--');
                plt_obj(i).MarkerFaceColor = 'r';
                plt_obj(i).Tag = "Hinge";
            end
        end
        function Export(obj,fid)
            if ~isempty(obj)
                for i = 1:length(obj)
                    if obj(i).isLocked
                        mni.printing.bdf.writeComment(fid,"RBE2s: Defines a locked hinge joint.");
                        mni.printing.bdf.writeColumnDelimiter(fid,"short")
                        mni.printing.cards.RBE2(obj(i).ID,obj(i).Points(1).ID,123456,obj(i).Points(2).ID).writeToFile(fid);
                    else
                        mni.printing.bdf.writeComment(fid,"RJOINT, CBUSH, PBUSH: Defines a hinge joint.");
                        mni.printing.bdf.writeColumnDelimiter(fid,"short")
                        mni.printing.cards.RJOINT(obj(i).ID,obj(i).Points(1).ID,obj(i).Points(2).ID,'CB','12356').writeToFile(fid);
                        mni.printing.cards.CBUSH(obj(i).ID+1,obj(i).PID,obj(i).Points(1).ID,...
                            obj(i).Points(2).ID,'CID',obj(i).Points(1).InputCoordSys.ID).writeToFile(fid);
                        mni.printing.cards.PBUSH(obj(i).PID,'K',[0,0,0,obj(i).K,0,0],...
                                'B',[0,0,0,obj(i).C,0,0]).writeToFile(fid);
                    end
                end
            end
        end
    end
end

