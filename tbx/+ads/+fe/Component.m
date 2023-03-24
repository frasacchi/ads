classdef Component < handle
    properties
        Name = "DefaultComponent";
        CoordSys (:,1) ads.fe.CoordSys = ads.fe.CoordSys.Base;
        Points (:,1) ads.fe.Point = ads.fe.Point.empty;
        Beams (:,1) ads.fe.Beam = ads.fe.Beam.empty;
        Materials (:,1) ads.fe.Material = ads.fe.Material.empty;
        Masses (:,1) ads.fe.Mass = ads.fe.Mass.empty;
        RigidBars (:,1) ads.fe.RigidBar = ads.fe.RigidBar.empty;
        Constraints (:,1) ads.fe.Constraint = ads.fe.Constraint.empty;
        Components (:,1) ads.fe.Component = ads.fe.Component.empty;
        Hinges (:,1) ads.fe.Hinge = ads.fe.Hinge.empty;
        Moments (:,1) ads.fe.Moment = ads.fe.Moment.empty;
        Forces(:,1) ads.fe.Force = ads.fe.Force.empty;
        AeroSurfaces (:,1) ads.fe.AeroSurface = ads.fe.AeroSurface.empty;
        AeroSettings (:,1) ads.fe.AeroSettings = ads.fe.AeroSettings.empty;
    end
    methods
        function obj1 = plus(obj1,obj2)
            if ~isa(obj2,"ads.fe.Component")
                error("Can't add data types of %s and %s",class(obj1),class(obj2))
            end
            names = fieldnames(obj1);
            for i = 1:length(names)
                if isa(obj1.(names{i}),'ads.fe.Element') || isa(obj1.(names{i}),'ads.fe.Component')
                    obj1.(names{i}) = [obj1.(names{i});obj2.(names{i})];
                end
            end
        end
        function plt_obj = draw(obj)
            plt_obj = [];
            for i = 1:length(obj)
            names = fieldnames(obj(i));
            for j = 1:length(names)
                if isa(obj(i).(names{j}),'ads.fe.Element') || isa(obj(i).(names{j}),'ads.fe.Component')
                    plt_obj = [plt_obj,obj(i).(names{j}).draw()];
                end
            end
            end
        end
        function obj = UpdateTag(obj,tag)
            names = fieldnames(obj);
            for i = 1:length(names)
                if isa(obj.(names{i}),'ads.fe.Element')
                    for j = 1:length(obj.(names{i}))
                        obj.(names{i})(j).Tag = tag;
                    end
                end
            end
        end
        function obj = Flatten(obj)
            tmpComponents = obj.Components;
            obj.Components = ads.fe.Component.empty;
            for i = 1:length(tmpComponents)
                obj = obj + tmpComponents(i).Flatten();
            end
        end
        function [ids] = UpdateIDs(obj)
            ids = ads.fe.IDs;
            names = properties(obj);
            for i = 1:length(properties(obj))
                if isa(obj.(names{i}),'ads.fe.Element')
                    ids = obj.(names{i}).UpdateID(ids);
                end
            end
        end
        function filename = Export(obj,filename)
            fid = fopen(filename,"w");
            mni.printing.bdf.writeFileStamp(fid);
            mni.printing.bdf.writeHeading(fid,obj.Name)
            names = fieldnames(obj);
            for i = 1:length(names)
                if isa(obj.(names{i}),'ads.fe.Element')
                    obj.(names{i}).Export(fid);  
                end
            end
            fclose(fid);
        end
    end
    methods(Static)
    end
end

