import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:imageScanner/Scan/Details.dart';
import 'package:imageScanner/user/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class HomePage extends StatefulWidget {

  //We need the user id to create a image folder for a particular user

  String? userId;
  HomePage({Key? key , this.userId}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final keyOne = GlobalKey();

  //Firebase Cloud Implementation
  User? user = FirebaseAuth.instance.currentUser;
  UserModel loggedInUser = UserModel();
  //final VoidCallback? onPressed;
  bool textScanning = false;
  XFile? _image;
  XFile? _images;
  String? downloadURL;
  String scannedText = "";
  String? scannedText_email = "";
  String?scannedText_phone = "";
  String?  scannedText_website= "";

  final databaseRef = FirebaseDatabase.instance.ref();

  @override

  //Fetching Details about User
  final _formKey = GlobalKey<FormState>();
  @override
  void initState(){
    super.initState();
    FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get()
        .then((value){
      loggedInUser = UserModel.fromMap(value.data());
      setState(() {});
    });
  }

  //Checking the image exists or not , and then taking them to the scan page
  Future checkImage() async{
    if (_image == null)
    {
      showSnackbar("No Image Selected", Duration(milliseconds: 600));
    }
    else
    {
      uploadImage(_image);
    }
  }

  //SnackBar for the Image
  showSnackbar(String snackText , Duration d)
  {
    final snackBar = SnackBar(content: Text(snackText),duration: d);
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }



  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Image Scanner"),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.scanner_sharp),
              tooltip: "Scan",
            onPressed: () {checkImage();}),
        ],
        backgroundColor: Colors.red[300],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Container(
              padding: EdgeInsets.fromLTRB(15, 25, 15, 35),
              child: Text(
                "Hello ${loggedInUser.userName} , welcome!!",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),

              ),
            ),
            //this will create rounded rectangular thing
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 320,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(width: 250,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: Colors.white),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (!textScanning && _image == null )
                                Expanded(
                                    child: Center(
                                      child: Text("NO image selected",style: TextStyle(fontSize: 13,fontWeight: FontWeight.w400),)
                                    )
                                ),
                              if (_image != null)
                                Expanded(
                                    child: Image.file(File(_image!.path),
                                      fit: BoxFit.contain
                                    )
                                )
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          minimumSize: Size(200, 50),
                          textStyle: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500),
                          primary: Colors.white,
                          onPrimary: Colors.black
                      ),
                      child: Text("Upload From Gallery"),
                      onPressed: () {getImage(ImageSource.gallery);},
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          minimumSize: Size(235, 50),
                          textStyle: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500),
                          primary: Colors.white,
                          onPrimary: Colors.black
                      ),
                      child: Text("Pick from Camera"),
                      onPressed: () {getImage(ImageSource.camera);},
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Identify the Text from the image
  Future getImage(ImageSource source) async {
    try {
      final pickedImage = await ImagePicker().pickImage(source: source);
      if (pickedImage != null) {
        textScanning = true;
        _image = pickedImage;
        setState(() {});
        recognisedText(pickedImage);
        _images=_image;
        return _images;
      }
      else if(pickedImage == null){
        showSnackbar("No Image Selected", Duration(milliseconds: 600));
      }
    } catch (e) {
      textScanning = false;
      _image = null;
      scannedText = "Error occured while scanning";
      setState(() {});
    }
  }

  //Identifying Text from Image using Google ML KIT (MAIN)
  Future recognisedText(XFile image) async {
    String Email = r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]{2,3}";
    String Phone =r"^((((\+){1}91){1})?-? ?-?[0-9]{1}[0-9]{9})$";
    String webSite=r"^(https:\/\/www\.|http:\/\/www\.|https:\/\/|http:\/\/|www\.)?[a-zA-Z0-9\-_$]+\.[a-zA-Z]{2,5}$";
    //r"^(https:\/\/www\.|http:\/\/www\.|https:\/\/|http:\/\/|www\.)[a-zA-Z0-9\-_$]+\.[a-zA-Z]{2,5}$"

    RegExp regEx = RegExp(Email);
    RegExp regEx_2=RegExp(Phone);
    RegExp regEx_3=RegExp(webSite);
    String mailAddress = "";
    String phoneNumber="";
    String website="";
    bool maill=true;

    final inputImage = InputImage.fromFilePath(image.path);
    final textDetector = GoogleMlKit.vision.textDetector();
    RecognisedText recognisedText = await textDetector.processImage(inputImage);
    await textDetector.close();
    scannedText = "";
    for (TextBlock block in recognisedText.blocks) {
      for (TextLine line in block.lines) {
        if (regEx.hasMatch(line.text)) {
          mailAddress += line.text+'\n';
          if (this.mounted) {
            setState(() {
              scannedText_email = mailAddress;
            });
          }
        }
      }
    }
    for (TextBlock block in recognisedText.blocks) {
      for (TextLine line in block.lines) {
        if (regEx_2.hasMatch(line.text)) {
          phoneNumber+=line.text+'\n';
          if (this.mounted) {
            setState(() {
              //scannedText = mailAddress;
              scannedText_phone= phoneNumber;
              //scannedText_website= website;
            });
          }
        }
      }
    }
    for (TextBlock block in recognisedText.blocks) {
      for (TextLine line in block.lines) {
        if (regEx_3.hasMatch(line.text)) {
          website +=line.text + '\n';
          if (this.mounted) {
            setState(() {
              //scannedText = mailAddress;
              //scannedText_phone= phoneNumber;
              scannedText_website= website;
            });
          }
        }
      }
    }
    return [scannedText_email,scannedText_phone,scannedText_website,maill,];
  }

  //Uploading images and text to realtime database or firebase storage
  Future uploadImage(images) async
  {
    //A CIRCULAR PROGRESS BAR IS SHOWN
    showDialog(
        context: context,
        builder: (context) {
          return Center(child: CircularProgressIndicator());
        });
    /*
    showDialog(context: context, builder:(context){
      return Center(child:
      CircularProgressIndicator(
        backgroundColor: Colors.pink,
        strokeWidth: 8,
      ));
    });
     */
    //Converting XFile to File cause images or texts cant be added to firebase storage without the filename because image needs the path to be uploaded.
    File file = File(_image!.path);
    final postID = DateTime.now().millisecondsSinceEpoch.toString();
    FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
    Reference ref = FirebaseStorage.instance
        .ref()
        .child("${widget.userId}/Images")
        .child("post_$postID");
    await ref.putFile(file);
    downloadURL = await ref.getDownloadURL();
    //uploading to cloud firestore
    await firebaseFirestore.collection("users")
        .doc(widget.userId)
        .collection("images")
        .add({'downloadURL':downloadURL,'Email':scannedText_email,'Phone':scannedText_phone,'Website':scannedText_website});
        // .whenComplete(() => print("Image Uploaded Successful"));

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Details(images: _image,email: scannedText_email,phone:scannedText_phone,website: scannedText_website)));
  }

}

