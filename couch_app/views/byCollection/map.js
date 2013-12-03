function (doc)
{
  if (doc.collection != null)
    emit(doc.collection, doc)
}