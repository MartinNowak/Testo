import { Injectable } from '@angular/core';
import { Headers, Http, RequestMethod } from '@angular/http';
import 'rxjs/add/operator/map';
import { Runner } from './api'

@Injectable()
export class BackendService {
  constructor(private _http: Http) {
  }

  runners() {
    var url = 'api/runners';
    return this._http.get(url).map(res => <Runner[]>res.json());
  }
}
