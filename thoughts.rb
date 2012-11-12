X.trans do
  X.query(:tblSamuraiUser).join { ... }.where {
    upp = tblSamuraiUserProduct

    upp.userProductId == 188...


    first_cond = (email == "arlen@noblesamurai.com").and(userId > 10000)
    second_cond = x.and(y).and(z)

    blah = tblSamuraiUserProduct.columnName == xyzzy

    first_cond.or second_cond.or blah
  }

  my_new_record = my_old_record.merge(changes)

  X.update(:tblSamuraiUser).where { userId == 610610 }.update(changes)
end

X.query(:tblSamuraiUser).where(lambda {email == "arlen@noblesamurai.com"}, lambda {userId > 10000})

#Tim's thoughts:
#
#- We need to know what we think of statically defined r'ships b/w tables vs defining everything in place where the query is performed.
#  Is the ActiveRecord way of defining r'ships b/w tables a good model for us?
#  Or do we have some alternative way of statically defining this stuff?  Or do we dynamically infer it?
#
#  I am thinking we need a means to join which is based again on a simple hash.  For example, the hash
#  could look like: {:from => :tblSamuraiUser.id, :to => tblSamuraiUserProduct.user_id}
#  Then, the user could define these hash as constants, eg UserToUserProduct = blah
#  The joins could then be brought in to the query object (perhaps a .joins method, which can either take a single hash or an array),
#  as with a :joins key, which might map to an array of joins options hashes.
#
#  Anyway, those are my thoughts for now, we can chat further!
