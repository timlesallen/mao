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
