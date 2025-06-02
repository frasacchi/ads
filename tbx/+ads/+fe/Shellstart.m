classdef Shell < ads.fe.Element
    %BEAM Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Stations (:,1) ads.fe.BeamStation
        ID double = nan;
        PID double = nan;
        G0 ads.fe.Point = ads.fe.Point.empty
        yDir (3,1) double = [0;1;0];
        K = 1;
        ExportType string {mustBeMember(ExportType,{'CBAR','CBEAM'})} = "CBEAM";
        ExportLongFormat logical = true;
    end

    methods
        function obj = Shell(stations,opts)
            arguments
                stations (2,1) ads.fe.BeamStation
                opts.yDir (3,1) double = [0;1;0];
            end
            obj.Stations = stations;
            obj.yDir = opts.yDir;
        end
        function m = GetMass(obj)
            m = zeros(size(obj));
            for i = 1:length(obj)
                tmp_m = 0;
                for j = 2:length(obj(i).Stations)
                    h = obj(i).Stations(j).Point.GlobalPos - obj(i).Stations(j-1).Point.GlobalPos;
                    h = norm(h);
                    A1 = obj(i).Stations(j-1).A;
                    A2 = obj(i).Stations(j).A;
                    V = h*(A1+A2+sqrt(A1*A2))/3;
                    tmp_m = tmp_m + V*obj(i).Stations(j-1).Mat.rho;
                end
                m(i) = tmp_m;
            end
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.EID;
                ids.EID = ids.EID + 1;
                obj(i).PID = ids.PID;
                ids.PID = ids.PID + 1;
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
            for i = 1:length(obj)
                st = [obj(i).Stations];
                ps = [[st(1,:).Point],st(2,end).Point];
                Xs = [ps.GlobalPos];
                plt_obj(i) = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'co-');
                plt_obj(i).MarkerFaceColor = 'c';
                plt_obj(i).Tag = "Beam";
            end
        end
        function Export(obj,fid)
            names = ["CBEAM","CBAR"];
            if ~isempty(obj)
                for i = 1:length(names)
                    idx= [obj.ExportType] == names(i);
                    if nnz(idx)>0
                        switch names(i)
                            case "CBEAM"
                                obj(idx).ExportToCBEAM(fid);
                            case "CBAR"
                                obj(idx).ExportToCBAR(fid);
                        end
                    end
                end
            end
        end
        function ExportToCBEAM(obj,fid)

            if ~isempty(obj)
                % print CBEAM elements
                mni.printing.bdf.writeComment(fid,"CBEAM : Defines a beam element.");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(obj)
                    Pa = obj(i).Stations(1).Point;
                    Pb = obj(i).Stations(end).Point;
                    if ~isempty(obj(i).G0)
                        tmpCard = mni.printing.cards.CBEAM(obj(i).ID,obj(i).PID,Pa.ID,Pb.ID,"G0",obj(i).G0.ID);
                    else
                        tmpCard = mni.printing.cards.CBEAM(obj(i).ID,obj(i).PID,Pa.ID,Pb.ID,"x",obj(i).yDir);
                    end
                    tmpCard.writeToFile(fid);
                end
                % print PBEAM elements
                mni.printing.bdf.writeComment(fid,"PBEAM : Defines the properties of a tapered beam element.");
                mni.printing.bdf.writeColumnDelimiter(fid,"long")
                for i = 1:length(obj)
                    % create matran sections
                    matSecs = mni.printing.cards.BeamSection.empty;
                    Xa = obj(i).Stations(1).Point.X;
                    Xb = obj(i).Stations(end).Point.X;
                    for j = 1:length(obj(i).Stations)
                        matSecs(j) = obj(i).Stations(j).ToMatranSection(Xa,Xb);
                    end
                    %print PBEAM cards
                    tmpCard = mni.printing.cards.PBEAM(obj(i).PID,obj(i).Stations(1).Mat.ID,matSecs,K=[1,1]*obj(i).K);
                    tmpCard.LongFormat = obj.ExportLongFormat;
                    tmpCard.writeToFile(fid);
                end
            end
        end
        function ExportToCBAR(obj,fid)
            if ~isempty(obj)
                % print CBEAM elements
                mni.printing.bdf.writeComment(fid,"CBAR : Defines a beam element.");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(obj)
                    Pa = obj(i).Stations(1).Point;
                    Pb = obj(i).Stations(end).Point;
                    if ~isempty(obj(i).G0)
                        tmpCard = mni.printing.cards.CBAR(obj(i).ID,obj(i).PID,Pa.ID,Pb.ID,"G0",obj(i).GID);
                    else
                        tmpCard = mni.printing.cards.CBAR(obj(i).ID,obj(i).PID,Pa.ID,Pb.ID,"X",obj(i).yDir);
                    end
                    tmpCard.writeToFile(fid);
                end
                % print PBAR elements
                mni.printing.bdf.writeComment(fid,"PBAR : Defines the properties of a tapered beam element.");
                mni.printing.bdf.writeColumnDelimiter(fid,"long")
                for i = 1:length(obj)
                    % create matran sections
                    Xa = obj(i).Stations(1).Point.X;
                    Xb = obj(i).Stations(end).Point.X;
                    matSec = obj(i).Stations(1).ToMatranSection(Xa,Xb);
                    %print PBEAM cards
                    tmpCard = mni.printing.cards.PBAR(obj(i).PID,obj(i).Stations(1).Mat.ID,matSec);
                    tmpCard.LongFormat = obj.ExportLongFormat;
                    tmpCard.writeToFile(fid);
                end
            end
        end
    end
    methods(Static)
        function obj = Bar(PointA,PointB,height,width,Material)
            stations = ads.fe.BeamStation.Bar(PointA,height,width,Mat=Material);
            stations(2) = ads.fe.BeamStation.Bar(PointB,height,width,Mat=Material);
            obj = ads.fe.Beam(stations);
        end
        function obj = FromBaffStations(sts,ps,Mat)
            arguments
                sts (:,1) baff.station.Beam
                ps (:,1) ads.fe.Point
                Mat ads.fe.Material;
            end
            stations    = ads.fe.BeamStation.FromBaffStation(sts(1),ps(1),Mat);
            stations(2) = ads.fe.BeamStation.FromBaffStation(sts(2),ps(2),Mat);
%             yDir = ps(1).InputCoordSys.getAglobal()*[0;1;0];
            yDir = [1;0;0];
            %make beam
            obj = ads.fe.Beam(stations,yDir=yDir);
        end
    end
end

