base_path = 'G:\tmp\00_igkl\hql073\250626_hql073_whisker\HQL073_whisker250623_007';
%%

peripheral_session = peripheral_mdf(base_path);
%%
peripheral_session = peripheral_session.loadraw_analogdata;
%%
peripheral_session = peripheral_session.loadbehavior;
%%

