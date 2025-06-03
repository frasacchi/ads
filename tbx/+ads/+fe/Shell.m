classdef Shell < ads.fe.Element
    %BEAM Summary of this class goes here
    %   Detailed explanation goes here

    properties
        %Stations (:,1) ads.fe.BeamStation
        ID double = nan;
        PID double = nan;
        G1 ads.fe.Point=ads.fe.Point.empty(0,1);%[];% =ads.fe.Point.empty;%[0;0;0;0];
        %G0 ads.fe.Point = ads.fe.Point.empty
        %yDir (3,1) double = [0;1;0];
        %K = 1;
        Mat ads.fe.Material = ads.fe.Material.empty;

        Thickness double {mustBePositive}= 1e-6;
        ExportLongFormat logical = true;
    end

    methods
        function obj = Shell(G1,Mat,Thickness)
            arguments
                G1 (4,1) ads.fe.Point
                Mat ads.fe.Material 
                Thickness double
            end
            obj.G1=G1;
            obj.Mat = Mat;
            obj.Thickness = Thickness;
        end
        function m = GetMass(obj)
            m = zeros(size(obj));
            warning('shell mass estimation not implemented')
            % for i = 1:length(obj)
            % 
            % end
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.EID;
                ids.EID = ids.EID + 1;
                obj(i).PID = ids.PID;
                ids.PID = ids.PID + 1;
            end
        end
        % function plt_obj = drawElement(obj)
        % 
        % end
        function Export(obj,fid)

            obj(1).ExportToCQUAD4(fid);
        end

        function ExportToCQUAD4(obj,fid)

            if ~isempty(obj)
                % print CBEAM elements
                mni.printing.bdf.writeComment(fid,"CQUAD4: Defines a QUADRILATERAL element.");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(obj)
                    tmpCard = mni.printing.cards.CQUAD4(obj(i).EID,obj(i).PID,obj.G1);
                    tmpCard.writeToFile(fid);
                end
                % print PBEAM elements
                mni.printing.bdf.writeComment(fid,"PSHELL : Defines the properties of a SHELL element.");
                mni.printing.bdf.writeColumnDelimiter(fid,"long")

                tmpCard = mni.printing.cards.PSHELL(obj(i).PID,obj(i).Mat,obj(i).Thickness,obj(i).Mat,[],obj(i).Mat);
                tmpCard.LongFormat = obj.ExportLongFormat;
                tmpCard.writeToFile(fid);
                % end
            end
        end
    end

end

