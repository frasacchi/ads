classdef Mass < ads.fe.Element
    %MASS Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Point ads.fe.Point
        mass (1,1) double;
        InertiaTensor (3,3) double= zeros(3);
        ID double = nan;
    end

    methods
        function obj = Mass(mass,Point,opts)
            arguments
                mass
                Point ads.fe.Point
                opts.Ixx = 0;
                opts.Iyy = 0;
                opts.Izz = 0;
                opts.Ixy = 0;
                opts.Ixz = 0;
                opts.Iyz = 0;
            end
            %MASS Construct an instance of this class
            %   Detailed explanation goes here
            obj.mass = mass;
            obj.Point = Point;
            obj.InertiaTensor = [opts.Ixx,opts.Ixy,opts.Ixz;...
                opts.Ixy,opts.Iyy,opts.Iyz;...
                opts.Ixz,opts.Iyz,opts.Izz];
        end
        function m = GetMass(obj)
            m = size(obj)
            for i = 1:length(obj)
                m(i) = obj(i).mass;
            end
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.EID;
                ids.EID = ids.EID + 1;
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
            plt_obj = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'b^');
            plt_obj.MarkerFaceColor = 'b';
            plt_obj.MarkerSize = 6;
            plt_obj.Tag = "Mass";

            plt_obj.ButtonDownFcn = @(src, event) displayMassInfo(src, event, obj);

            function displayMassInfo(src, event, obj)

                clickPoint = event.IntersectionPoint;

                allPoints = [src.XData; src.YData; src.ZData];

                distances = vecnorm(allPoints - clickPoint');
                [~, idx] = min(distances);

                clickedMassObject = obj(idx);
                mass_call = clickedMassObject.mass*1e3;
                inertia_call = diag(clickedMassObject.InertiaTensor)*1e6;
                Xs_call = clickedMassObject.Point.GlobalPos*1e3;

                fprintf('--- Mass %d ---\n', idx);
                fprintf('Mass (g): %.3f\n', mass_call);
                fprintf('Inertia (kgmm^2): [%.3f, %.3f, %.3f]\n', inertia_call(1), inertia_call(2), inertia_call(3));
                fprintf('Position (mm): [%.3f, %.3f, %.3f]\n\n', Xs_call(1),Xs_call(2),Xs_call(3));

                % === Add annotation on the clicked point ===
                hold on
                txt = sprintf('Mass %d', idx);
                text(src.XData(idx), src.YData(idx), src.ZData(idx), txt, ...
                    'FontSize', 12, 'FontWeight', 'bold', 'Color', 'b', ...
                    'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
                hold off

            end
        end
        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"CONM2 : Defines a concentrated mass at a grid point");
                mni.printing.bdf.writeColumnDelimiter(fid,"long")
                for i = 1:length(obj)
                    I = obj(i).InertiaTensor;
                    tmpCard = mni.printing.cards.CONM2(obj(i).ID,obj(i).Point.ID,obj(i).mass,...
                        "I",[I(1,1),I(2,1),I(2,2),I(3,1),I(3,2),I(3,3)],"CID",obj(i).Point.InputCoordSys.ID);
                    tmpCard.LongFormat = true;
                    tmpCard.writeToFile(fid);
                end
            end
        end

    end
end

