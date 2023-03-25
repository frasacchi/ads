function inv_dof = inv_dof(dof)
    dof =num2str(dof);
    inv_dof = '';
    for i=1:6
        if ~contains(dof,num2str(i))
            inv_dof = [inv_dof,num2str(i)];
        end
    end
    inv_dof = str2num(inv_dof);
end
